module SerdeMsgPack

using Dates
using UUIDs

export parse_msgpack, from_msgpack, try_from_msgpack, to_msgpack

import ..ParseError, ..SerdeError, ..to_deser, ..DefaultStrategy
import ..ser_name, ..ser_value, ..ser_type, ..ser_skip

const MP_NIL      = UInt8(0xc0)
const MP_FALSE    = UInt8(0xc2)
const MP_TRUE     = UInt8(0xc3)
const MP_BIN8     = UInt8(0xc4)
const MP_BIN16    = UInt8(0xc5)
const MP_BIN32    = UInt8(0xc6)
const MP_EXT8     = UInt8(0xc7)
const MP_EXT16    = UInt8(0xc8)
const MP_EXT32    = UInt8(0xc9)
const MP_FLOAT32  = UInt8(0xca)
const MP_FLOAT64  = UInt8(0xcb)
const MP_UINT8    = UInt8(0xcc)
const MP_UINT16   = UInt8(0xcd)
const MP_UINT32   = UInt8(0xce)
const MP_UINT64   = UInt8(0xcf)
const MP_INT8     = UInt8(0xd0)
const MP_INT16    = UInt8(0xd1)
const MP_INT32    = UInt8(0xd2)
const MP_INT64    = UInt8(0xd3)
const MP_FIXEXT1  = UInt8(0xd4)
const MP_FIXEXT2  = UInt8(0xd5)
const MP_FIXEXT4  = UInt8(0xd6)
const MP_FIXEXT8  = UInt8(0xd7)
const MP_FIXEXT16 = UInt8(0xd8)
const MP_STR8     = UInt8(0xd9)
const MP_STR16    = UInt8(0xda)
const MP_STR32    = UInt8(0xdb)
const MP_ARR16    = UInt8(0xdc)
const MP_ARR32    = UInt8(0xdd)
const MP_MAP16    = UInt8(0xde)
const MP_MAP32    = UInt8(0xdf)

const MP_EXT_TIMESTAMP = Int8(-1)
const MP_UNIX_EPOCH    = Dates.DateTime(1970, 1, 1)

const MP_DEFAULT_MAX_DEPTH = 1000

@inline function _mp_check_remaining(io::IO, n::Integer)
    n < 0 && throw(ParseError("MsgPack", "negative length: $n", ErrorException("bad length")))
    if applicable(bytesavailable, io)
        avail = bytesavailable(io)
        n > avail && throw(ParseError("MsgPack", "length $n exceeds remaining $(avail) bytes", ErrorException("truncated")))
    end
    return nothing
end

@inline function _mp_check_count(io::IO, n::Integer, bytes_per_elem::Integer = 1)
    n < 0 && throw(ParseError("MsgPack", "negative count: $n", ErrorException("bad count")))
    if applicable(bytesavailable, io)
        avail = bytesavailable(io)
        Int(n) * Int(bytes_per_elem) > avail &&
            throw(ParseError("MsgPack", "element count $n exceeds remaining bytes ($avail)", ErrorException("oversized")))
    end
    return nothing
end

function _msgpack_read_str(io::IO, n::Int)
    _mp_check_remaining(io, n)
    return String(read(io, n))
end

function _msgpack_read_bin(io::IO, n::Int)
    _mp_check_remaining(io, n)
    return read(io, n)
end

function _msgpack_read_arr(io::IO, n::Int, depth::Int, ::Type{D}, max_depth::Int) where {D<:AbstractDict}
    _mp_check_count(io, n, 1)
    result = Vector{Any}(undef, n)
    for i in 1:n
        result[i] = _msgpack_read(io, depth + 1, D, max_depth)
    end
    return result
end

function _msgpack_read_map(io::IO, n::Int, depth::Int, ::Type{D}, max_depth::Int) where {D<:AbstractDict}
    _mp_check_count(io, n, 2)
    result = D()
    sizehint!(result, n)
    for _ in 1:n
        k = _msgpack_read(io, depth + 1, D, max_depth)
        v = _msgpack_read(io, depth + 1, D, max_depth)
        result[string(k)] = v
    end
    return result
end

function _msgpack_read_timestamp(io::IO, len::Int)
    if len == 4
        s = Int64(ntoh(read(io, UInt32)))
        return MP_UNIX_EPOCH + Dates.Second(s)
    elseif len == 8
        ts64 = ntoh(read(io, UInt64))
        ns = Int64(ts64 >> 34)
        s  = Int64(ts64 & 0x00000003ffffffff)
        return MP_UNIX_EPOCH + Dates.Second(s) + Dates.Millisecond(div(ns, 1_000_000))
    elseif len == 12
        ns = Int64(ntoh(read(io, UInt32)))
        s  = ntoh(read(io, Int64))
        return MP_UNIX_EPOCH + Dates.Second(s) + Dates.Millisecond(div(ns, 1_000_000))
    else
        throw(ParseError("MsgPack", "invalid timestamp extension length: $len", ErrorException("bad ext")))
    end
end

function _msgpack_read_ext(io::IO, len::Int)
    _mp_check_remaining(io, len + 1)
    type_byte = read(io, Int8)
    type_byte == MP_EXT_TIMESTAMP && return _msgpack_read_timestamp(io, len)
    # Return raw body for unknown ext types; the type tag is documented as
    # discarded in `parse_msgpack` (see docstring).
    return read(io, len)
end

@inline _mp_int64_or_uint64(v::UInt64) = v <= typemax(Int64) ? Int64(v) : v

function _msgpack_read(io::IO, depth::Int = 0, ::Type{D} = Dict{String,Any}, max_depth::Int = MP_DEFAULT_MAX_DEPTH) where {D<:AbstractDict}
    depth > max_depth && throw(ParseError("MsgPack", "nesting exceeds depth limit ($max_depth)", ErrorException("depth")))
    b = read(io, UInt8)

    b <= 0x7f && return Int64(b)
    b >= 0xe0 && return Int64(reinterpret(Int8, b))

    b & 0xf0 == 0x80 && return _msgpack_read_map(io, Int(b & 0x0f), depth, D, max_depth)
    b & 0xf0 == 0x90 && return _msgpack_read_arr(io, Int(b & 0x0f), depth, D, max_depth)
    b & 0xe0 == 0xa0 && return _msgpack_read_str(io, Int(b & 0x1f))

    b == MP_NIL   && return nothing
    b == MP_FALSE && return false
    b == MP_TRUE  && return true

    b == MP_FLOAT32 && return ntoh(read(io, Float32))
    b == MP_FLOAT64 && return ntoh(read(io, Float64))

    b == MP_UINT8  && return Int64(read(io, UInt8))
    b == MP_UINT16 && return Int64(ntoh(read(io, UInt16)))
    b == MP_UINT32 && return Int64(ntoh(read(io, UInt32)))
    b == MP_UINT64 && return _mp_int64_or_uint64(ntoh(read(io, UInt64)))

    b == MP_INT8  && return Int64(read(io, Int8))
    b == MP_INT16 && return Int64(ntoh(read(io, Int16)))
    b == MP_INT32 && return Int64(ntoh(read(io, Int32)))
    b == MP_INT64 && return ntoh(read(io, Int64))

    b == MP_BIN8  && return _msgpack_read_bin(io, Int(read(io, UInt8)))
    b == MP_BIN16 && return _msgpack_read_bin(io, Int(ntoh(read(io, UInt16))))
    b == MP_BIN32 && return _msgpack_read_bin(io, Int(ntoh(read(io, UInt32))))

    b == MP_STR8  && return _msgpack_read_str(io, Int(read(io, UInt8)))
    b == MP_STR16 && return _msgpack_read_str(io, Int(ntoh(read(io, UInt16))))
    b == MP_STR32 && return _msgpack_read_str(io, Int(ntoh(read(io, UInt32))))

    b == MP_ARR16 && return _msgpack_read_arr(io, Int(ntoh(read(io, UInt16))), depth, D, max_depth)
    b == MP_ARR32 && return _msgpack_read_arr(io, Int(ntoh(read(io, UInt32))), depth, D, max_depth)

    b == MP_MAP16 && return _msgpack_read_map(io, Int(ntoh(read(io, UInt16))), depth, D, max_depth)
    b == MP_MAP32 && return _msgpack_read_map(io, Int(ntoh(read(io, UInt32))), depth, D, max_depth)

    b == MP_FIXEXT1  && return _msgpack_read_ext(io, 1)
    b == MP_FIXEXT2  && return _msgpack_read_ext(io, 2)
    b == MP_FIXEXT4  && return _msgpack_read_ext(io, 4)
    b == MP_FIXEXT8  && return _msgpack_read_ext(io, 8)
    b == MP_FIXEXT16 && return _msgpack_read_ext(io, 16)
    b == MP_EXT8     && return _msgpack_read_ext(io, Int(read(io, UInt8)))
    b == MP_EXT16    && return _msgpack_read_ext(io, Int(ntoh(read(io, UInt16))))
    b == MP_EXT32    && return _msgpack_read_ext(io, Int(ntoh(read(io, UInt32))))

    throw(ParseError("MsgPack", "unknown format byte: 0x$(string(b, base=16, pad=2))", ErrorException("invalid byte")))
end

"""
    parse_msgpack(x::Vector{UInt8}) -> Any

Decode a MessagePack byte array into Julia data structures without mapping to a target type.

Returns the raw decoded value: a `Dict{String,Any}` for MsgPack maps, a `Vector{Any}` for
arrays, or a scalar (`Int64`, `Float64`, `String`, `Bool`, `Nothing`, `DateTime`,
`Vector{UInt8}`) for primitive values.

The MsgPack timestamp extension type (-1) is decoded as `DateTime`.

# Arguments
- `x::Vector{UInt8}`: the raw MessagePack bytes.

# Returns
The decoded Julia value.

# Throws
- [`ParseError`](@ref): if `x` contains invalid MessagePack.

# Examples
```julia
julia> bytes = to_msgpack(Dict("x" => 1, "y" => 2));

julia> parse_msgpack(bytes)
Dict{String, Any}("x" => 1, "y" => 2)
```

See also: [`from_msgpack`](@ref), [`try_from_msgpack`](@ref).
"""
function parse_msgpack end

function parse_msgpack(x::Vector{UInt8};
                       dict_type::Type{D} = Dict{String,Any},
                       max_depth::Int = MP_DEFAULT_MAX_DEPTH,
                       kw...) where {D<:AbstractDict}
    io = IOBuffer(x)
    try
        return _msgpack_read(io, 0, D, max_depth)
    catch e
        e isa SerdeError && rethrow(e)
        throw(ParseError("MsgPack", "invalid MsgPack data", e))
    finally
        close(io)
    end
end

"""
    from_msgpack(::Type{T}, x::Vector{UInt8}) -> T
    from_msgpack(strategy, ::Type{T}, x::Vector{UInt8}) -> T
    from_msgpack(f::Function, x::Vector{UInt8}) -> Any

Decode a MessagePack byte array and deserialize it into type `T`.

Pass a context object `strategy` (e.g. [`CamelCase()`](@ref)) to apply global field-renaming.

# Arguments
- `::Type{T}`: target type to construct.
- `x::Vector{UInt8}`: raw MsgPack bytes.
- `strategy`: optional context object.

# Returns
A value of type `T`.

# Throws
- [`ParseError`](@ref): if `x` is invalid MsgPack.
- [`MissingFieldError`](@ref): if a required struct field is absent.
- [`TypeMismatchError`](@ref): if a value cannot be coerced to the field type.

# Examples
```julia
julia> struct Point; x::Int; y::Int; end

julia> bytes = to_msgpack(Point(1, 2));

julia> from_msgpack(Point, bytes)
Point(1, 2)
```

See also: [`try_from_msgpack`](@ref), [`to_msgpack`](@ref), [`parse_msgpack`](@ref).
"""
function from_msgpack(strategy, ::Type{T}, x::Vector{UInt8}; kw...) where {T}
    return to_deser(strategy, T, parse_msgpack(x; kw...))
end

from_msgpack(::Type{T}, x::Vector{UInt8}; kw...) where {T} = from_msgpack(DefaultStrategy(), T, x; kw...)
from_msgpack(::Type{Nothing}, ::Vector{UInt8}; kw...) = nothing
from_msgpack(::Type{Missing}, ::Vector{UInt8}; kw...) = missing

function from_msgpack(f::Function, x::Vector{UInt8}; kw...)
    object = parse_msgpack(x; kw...)
    return to_deser(f(object), object)
end

# ── Error-safe deserialization ──

function _try_wrap(f, args...; kw...)
    try
        return f(args...; kw...)
    catch e
        return e isa SerdeError ? e : ParseError("MsgPack", string(e), e)
    end
end

"""
    try_from_msgpack(::Type{T}, x::Vector{UInt8}) -> Union{T, SerdeError}
    try_from_msgpack(strategy, ::Type{T}, x::Vector{UInt8}) -> Union{T, SerdeError}

Like [`from_msgpack`](@ref) but returns a [`SerdeError`](@ref) instead of throwing on failure.

# Returns
- `T` on success.
- A [`ParseError`](@ref) or [`DeserError`](@ref) subtype on failure.

See also: [`from_msgpack`](@ref), [`SerdeError`](@ref).
"""
try_from_msgpack(::Type{T}, x::Vector{UInt8})           where {T} = _try_wrap(from_msgpack, T, x)
try_from_msgpack(strategy, ::Type{T}, x::Vector{UInt8}) where {T} = _try_wrap(from_msgpack, strategy, T, x)

function _msgpack_map_header!(io::IO, n::Int)
    if n <= 15
        write(io, UInt8(0x80 + n))
    elseif n <= 0xffff
        write(io, MP_MAP16); write(io, hton(UInt16(n)))
    else
        write(io, MP_MAP32); write(io, hton(UInt32(n)))
    end
end

function _msgpack_arr_header!(io::IO, n::Int)
    if n <= 15
        write(io, UInt8(0x90 + n))
    elseif n <= 0xffff
        write(io, MP_ARR16); write(io, hton(UInt16(n)))
    else
        write(io, MP_ARR32); write(io, hton(UInt32(n)))
    end
end

# ── Context-aware serialization ──

_msgpack_write!(io::IO, strategy, ::Nothing) = write(io, MP_NIL)
_msgpack_write!(io::IO, strategy, ::Missing) = write(io, MP_NIL)

function _msgpack_write!(io::IO, strategy, val::Bool)
    write(io, val ? MP_TRUE : MP_FALSE)
end

function _msgpack_write!(io::IO, strategy, val::Integer)
    if val >= 0
        if val <= 0x7f
            write(io, UInt8(val))
        elseif val <= typemax(UInt8)
            write(io, MP_UINT8); write(io, UInt8(val))
        elseif val <= typemax(UInt16)
            write(io, MP_UINT16); write(io, hton(UInt16(val)))
        elseif val <= typemax(UInt32)
            write(io, MP_UINT32); write(io, hton(UInt32(val)))
        else
            write(io, MP_UINT64); write(io, hton(UInt64(val)))
        end
    else
        if val >= -32
            write(io, Int8(val))
        elseif val >= typemin(Int8)
            write(io, MP_INT8); write(io, Int8(val))
        elseif val >= typemin(Int16)
            write(io, MP_INT16); write(io, hton(Int16(val)))
        elseif val >= typemin(Int32)
            write(io, MP_INT32); write(io, hton(Int32(val)))
        else
            write(io, MP_INT64); write(io, hton(Int64(val)))
        end
    end
end

_msgpack_write!(io::IO, strategy, val::Float32) = (write(io, MP_FLOAT32); write(io, hton(val)))
_msgpack_write!(io::IO, strategy, val::Float64) = (write(io, MP_FLOAT64); write(io, hton(val)))
_msgpack_write!(io::IO, strategy, val::AbstractFloat) = _msgpack_write!(io, strategy, Float64(val))

function _msgpack_write!(io::IO, strategy, val::AbstractString)
    n = ncodeunits(val)
    if n <= 31
        write(io, UInt8(0xa0 + n))
    elseif n <= 0xff
        write(io, MP_STR8); write(io, UInt8(n))
    elseif n <= 0xffff
        write(io, MP_STR16); write(io, hton(UInt16(n)))
    else
        write(io, MP_STR32); write(io, hton(UInt32(n)))
    end
    write(io, val)
end

_msgpack_write!(io::IO, strategy, val::Symbol)         = _msgpack_write!(io, strategy, string(val))
_msgpack_write!(io::IO, strategy, val::AbstractChar)   = _msgpack_write!(io, strategy, string(val))
_msgpack_write!(io::IO, strategy, val::Enum)           = _msgpack_write!(io, strategy, string(val))
_msgpack_write!(io::IO, strategy, val::Type)           = _msgpack_write!(io, strategy, string(val))
_msgpack_write!(io::IO, strategy, val::Dates.TimeType) = _msgpack_write!(io, strategy, string(val))
_msgpack_write!(io::IO, strategy, val::UUID)           = _msgpack_write!(io, strategy, string(val))
_msgpack_write!(io::IO, strategy, val::Regex)          = _msgpack_write!(io, strategy, string(val))

function _msgpack_write!(io::IO, strategy, val::Dates.DateTime)
    unix_ms = Dates.value(val - MP_UNIX_EPOCH)
    seconds = fld(unix_ms, 1000)
    nanoseconds = mod(unix_ms, 1000) * 1_000_000

    if nanoseconds == 0 && 0 <= seconds <= typemax(UInt32)
        write(io, MP_FIXEXT4)
        write(io, MP_EXT_TIMESTAMP)
        write(io, hton(UInt32(seconds)))
    elseif 0 <= seconds <= 0x3ffffffff
        write(io, MP_FIXEXT8)
        write(io, MP_EXT_TIMESTAMP)
        write(io, hton((UInt64(nanoseconds) << 34) | UInt64(seconds)))
    else
        write(io, MP_EXT8)
        write(io, UInt8(12))
        write(io, MP_EXT_TIMESTAMP)
        write(io, hton(UInt32(nanoseconds)))
        write(io, hton(Int64(seconds)))
    end
end

function _msgpack_write!(io::IO, strategy, val::AbstractVector{UInt8})
    n = length(val)
    if n <= 0xff
        write(io, MP_BIN8); write(io, UInt8(n))
    elseif n <= 0xffff
        write(io, MP_BIN16); write(io, hton(UInt16(n)))
    else
        write(io, MP_BIN32); write(io, hton(UInt32(n)))
    end
    write(io, val)
end

function _msgpack_iterable!(io::IO, strategy, iter, n::Int)
    _msgpack_arr_header!(io, n)
    for item in iter
        _msgpack_write!(io, strategy, item)
    end
end

_msgpack_write!(io::IO, strategy, val::AbstractVector) = _msgpack_iterable!(io, strategy, val, length(val))
_msgpack_write!(io::IO, strategy, val::Tuple)          = _msgpack_iterable!(io, strategy, val, length(val))
_msgpack_write!(io::IO, strategy, val::AbstractSet)    = _msgpack_iterable!(io, strategy, val, length(val))

function _msgpack_write!(io::IO, strategy, A::AbstractArray{<:Any,N}) where {N}
    newdims = ntuple(_ -> :, N - 1)
    n = size(A, N)
    _msgpack_arr_header!(io, n)
    for j in axes(A, N)
        _msgpack_write!(io, strategy, view(A, newdims..., j))
    end
end

function _msgpack_write!(io::IO, strategy, val::Pair)
    _msgpack_map_header!(io, 1)
    _msgpack_write!(io, strategy, first(val))
    _msgpack_write!(io, strategy, last(val))
end

function _msgpack_write!(io::IO, strategy, val::AbstractDict)
    _msgpack_map_header!(io, length(val))
    for (k, v) in val
        _msgpack_write!(io, strategy, k)
        _msgpack_write!(io, strategy, v)
    end
end

function _msgpack_write!(io::IO, strategy, val::NamedTuple)
    _msgpack_map_header!(io, length(val))
    for k in keys(val)
        _msgpack_write!(io, strategy, string(k))
        _msgpack_write!(io, strategy, val[k])
    end
end

function _msgpack_write!(io::IO, strategy, val::T) where {T}
    pairs = Tuple{Symbol,Any}[]
    N = fieldcount(T)
    Base.@nexprs 32 i -> begin
        if i <= N
            fn_i = fieldnames(T)[i]
            v_i = ser_type(strategy, T, ser_value(strategy, T, Val(fn_i), getfield(val, fn_i)))
            if !ser_skip(strategy, T, Val(fn_i), v_i)
                push!(pairs, (ser_name(strategy, T, Val(fn_i)), v_i))
            end
        end
    end
    if N > 32
        for field in fieldnames(T)[33:end]
            v = ser_type(strategy, T, ser_value(strategy, T, Val(field), getfield(val, field)))
            ser_skip(strategy, T, Val(field), v) && continue
            push!(pairs, (ser_name(strategy, T, Val(field)), v))
        end
    end
    _msgpack_map_header!(io, length(pairs))
    for (k, v) in pairs
        _msgpack_write!(io, strategy, string(k))
        _msgpack_write!(io, strategy, v)
    end
end

"""
    to_msgpack(data) -> Vector{UInt8}
    to_msgpack(strategy, data) -> Vector{UInt8}

Serialize `data` into a MessagePack byte array.

Structs are encoded as MsgPack maps with string keys. `Vector{UInt8}` fields are encoded
as MsgPack bin (binary). `DateTime` values use the MsgPack timestamp extension (-1).
`nothing` and `missing` are encoded as nil.

Pass a context object `strategy` (e.g. [`CamelCase()`](@ref)) to apply global field-renaming.

All serialization traits ([`Serde.ser_name`](@ref), [`Serde.ser_value`](@ref),
[`Serde.ser_skip`](@ref)) are applied.

# Arguments
- `data`: the value to serialize.
- `strategy`: optional context object.

# Returns
`Vector{UInt8}` — the raw MsgPack bytes.

# Examples
```julia
julia> struct Point; x::Int; y::Int; end

julia> bytes = to_msgpack(Point(1, 2));

julia> from_msgpack(Point, bytes)
Point(1, 2)
```

See also: [`from_msgpack`](@ref).
"""
function to_msgpack(strategy, data)::Vector{UInt8}
    io = IOBuffer()
    try
        _msgpack_write!(io, strategy, data)
        return take!(io)
    finally
        close(io)
    end
end

to_msgpack(data) = to_msgpack(DefaultStrategy(), data)

function to_msgpack(io::IO, data)
    _msgpack_write!(io, DefaultStrategy(), data)
    return nothing
end
function to_msgpack(io::IO, strategy, data)
    _msgpack_write!(io, strategy, data)
    return nothing
end

end
