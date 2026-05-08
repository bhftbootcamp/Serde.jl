module SerdeBson

using Dates
using UUIDs

export parse_bson, from_bson, try_from_bson, to_bson

import ..ParseError, ..SerdeError, ..to_deser, ..DefaultStrategy
import ..ser_name, ..ser_value, ..ser_type, ..ser_skip

const BSON_FLOAT64   = UInt8(0x01)
const BSON_STR       = UInt8(0x02)
const BSON_DOCUMENT  = UInt8(0x03)
const BSON_ARRAY     = UInt8(0x04)
const BSON_BINARY    = UInt8(0x05)
const BSON_BOOL      = UInt8(0x08)
const BSON_DATETIME  = UInt8(0x09)
const BSON_NULL      = UInt8(0x0a)
const BSON_REGEX     = UInt8(0x0b)
const BSON_INT32     = UInt8(0x10)
const BSON_INT64     = UInt8(0x12)
const BSON_TERMINATOR = UInt8(0x00)
const BSON_BIN_GENERIC = UInt8(0x00)

const BSON_UNIX_EPOCH = Dates.DateTime(1970, 1, 1)

function _bson_read_cstring(io::IO)
    buf = UInt8[]
    while true
        b = read(io, UInt8)
        b == 0x00 && break
        push!(buf, b)
    end
    return String(buf)
end

function _bson_read_string(io::IO)
    len = ltoh(read(io, Int32))
    s = String(read(io, len - 1))
    read(io, UInt8)
    return s
end

function _bson_read_value(io::IO, type_byte::UInt8)
    type_byte == BSON_FLOAT64  && return ltoh(read(io, Float64))
    type_byte == BSON_STR      && return _bson_read_string(io)
    type_byte == BSON_DOCUMENT && return _bson_read_document(io)
    type_byte == BSON_BOOL     && return read(io, UInt8) != 0x00
    type_byte == BSON_NULL     && return nothing
    type_byte == BSON_INT32    && return Int64(ltoh(read(io, Int32)))
    type_byte == BSON_INT64    && return ltoh(read(io, Int64))

    if type_byte == BSON_ARRAY
        doc = _bson_read_document(io)
        n = length(doc)
        result = Vector{Any}(undef, n)
        for i in 0:n-1
            result[i + 1] = doc[string(i)]
        end
        return result
    end

    if type_byte == BSON_BINARY
        len = ltoh(read(io, Int32))
        read(io, UInt8)
        return read(io, len)
    end

    if type_byte == BSON_DATETIME
        ms = ltoh(read(io, Int64))
        return BSON_UNIX_EPOCH + Dates.Millisecond(ms)
    end

    if type_byte == BSON_REGEX
        pattern = _bson_read_cstring(io)
        options = _bson_read_cstring(io)
        return Regex(pattern, options)
    end

    throw(ParseError("BSON", "unsupported BSON type: 0x$(string(type_byte, base=16, pad=2))", ErrorException("unknown type")))
end

function _bson_read_document(io::IO)
    ltoh(read(io, Int32))
    result = Dict{String,Any}()
    while true
        type_byte = read(io, UInt8)
        type_byte == BSON_TERMINATOR && break
        key = _bson_read_cstring(io)
        result[key] = _bson_read_value(io, type_byte)
    end
    return result
end

"""
    parse_bson(x::Vector{UInt8}) -> Dict{String, Any}

Decode a BSON byte array into a `Dict{String,Any}` without mapping to a target type.

Supported BSON types: Double (→ `Float64`), String (→ `String`), Document (→ `Dict`),
Array (→ `Vector`), Binary (→ `Vector{UInt8}`), Boolean (→ `Bool`), DateTime (→ `DateTime`),
Null (→ `nothing`), Int32/Int64 (→ `Int64`), Regex (→ `Regex`).

# Arguments
- `x::Vector{UInt8}`: the raw BSON bytes. Must represent a top-level BSON document.

# Returns
A `Dict{String, Any}` for the top-level document.

# Throws
- [`ParseError`](@ref): if `x` contains invalid or unsupported BSON.

# Examples
```julia
julia> bytes = to_bson(Dict("x" => 1, "y" => 2));

julia> parse_bson(bytes)
Dict{String, Any}("x" => 1, "y" => 2)
```

See also: [`from_bson`](@ref), [`try_from_bson`](@ref).
"""
function parse_bson end

function parse_bson(x::Vector{UInt8})
    io = IOBuffer(x)
    try
        return _bson_read_document(io)
    catch e
        e isa SerdeError && rethrow(e)
        throw(ParseError("BSON", "invalid BSON data", e))
    finally
        close(io)
    end
end

"""
    from_bson(::Type{T}, x::Vector{UInt8}) -> T
    from_bson(strategy, ::Type{T}, x::Vector{UInt8}) -> T
    from_bson(f::Function, x::Vector{UInt8}) -> Any

Decode a BSON byte array and deserialize it into type `T`.

Pass a context object `strategy` (e.g. [`CamelCase()`](@ref)) to apply global field-renaming.

# Arguments
- `::Type{T}`: target type to construct.
- `x::Vector{UInt8}`: raw BSON bytes.
- `strategy`: optional context object.

# Returns
A value of type `T`.

# Throws
- [`ParseError`](@ref): if `x` is invalid BSON.
- [`MissingFieldError`](@ref): if a required struct field is absent.
- [`TypeMismatchError`](@ref): if a value cannot be coerced to the field type.

# Examples
```julia
julia> struct Point; x::Int; y::Int; end

julia> bytes = to_bson(Point(1, 2));

julia> from_bson(Point, bytes)
Point(1, 2)
```

See also: [`try_from_bson`](@ref), [`to_bson`](@ref), [`parse_bson`](@ref).
"""
function from_bson(strategy, ::Type{T}, x::Vector{UInt8}) where {T}
    return to_deser(strategy, T, parse_bson(x))
end

from_bson(::Type{T}, x::Vector{UInt8}) where {T} = from_bson(DefaultStrategy(), T, x)
from_bson(::Type{Nothing}, ::Vector{UInt8}) = nothing
from_bson(::Type{Missing}, ::Vector{UInt8}) = missing

function from_bson(f::Function, x::Vector{UInt8})
    object = parse_bson(x)
    return to_deser(f(object), object)
end

function _try_wrap(f, args...; kw...)
    try
        return f(args...; kw...)
    catch e
        return e isa SerdeError ? e : ParseError("BSON", string(e), e)
    end
end

"""
    try_from_bson(::Type{T}, x::Vector{UInt8}) -> Union{T, SerdeError}
    try_from_bson(strategy, ::Type{T}, x::Vector{UInt8}) -> Union{T, SerdeError}

Like [`from_bson`](@ref) but returns a [`SerdeError`](@ref) instead of throwing on failure.

# Returns
- `T` on success.
- A [`ParseError`](@ref) or [`DeserError`](@ref) subtype on failure.

See also: [`from_bson`](@ref), [`SerdeError`](@ref).
"""
try_from_bson(::Type{T}, x; kw...)           where {T} = _try_wrap(from_bson, T, x; kw...)
try_from_bson(strategy, ::Type{T}, x; kw...) where {T} = _try_wrap(from_bson, strategy, T, x; kw...)

function _bson_cstring!(io::IO, s::AbstractString)
    write(io, s)
    write(io, BSON_TERMINATOR)
end

function _bson_subdocument!(f::Function, io::IO)
    buf = IOBuffer()
    try
        f(buf)
        content = take!(buf)
        write(io, htol(Int32(4 + length(content) + 1)))
        write(io, content)
        write(io, BSON_TERMINATOR)
    finally
        close(buf)
    end
end

function _bson_element!(io::IO, key::String, ::Nothing)
    write(io, BSON_NULL); _bson_cstring!(io, key)
end

function _bson_element!(io::IO, key::String, ::Missing)
    write(io, BSON_NULL); _bson_cstring!(io, key)
end

function _bson_element!(io::IO, key::String, val::Bool)
    write(io, BSON_BOOL); _bson_cstring!(io, key)
    write(io, val ? UInt8(0x01) : UInt8(0x00))
end

function _bson_element!(io::IO, key::String, val::Integer)
    if typemin(Int32) <= val <= typemax(Int32)
        write(io, BSON_INT32); _bson_cstring!(io, key)
        write(io, htol(Int32(val)))
    else
        write(io, BSON_INT64); _bson_cstring!(io, key)
        write(io, htol(Int64(val)))
    end
end

function _bson_element!(io::IO, key::String, val::AbstractFloat)
    write(io, BSON_FLOAT64); _bson_cstring!(io, key)
    write(io, htol(Float64(val)))
end

function _bson_element!(io::IO, key::String, val::AbstractString)
    write(io, BSON_STR); _bson_cstring!(io, key)
    n = ncodeunits(val) + 1
    write(io, htol(Int32(n)))
    write(io, val)
    write(io, BSON_TERMINATOR)
end

function _bson_element!(io::IO, key::String, val::Dates.DateTime)
    write(io, BSON_DATETIME); _bson_cstring!(io, key)
    ms = Dates.value(val - BSON_UNIX_EPOCH)
    write(io, htol(Int64(ms)))
end

function _bson_element!(io::IO, key::String, val::Regex)
    write(io, BSON_REGEX); _bson_cstring!(io, key)
    _bson_cstring!(io, val.pattern)
    opts = ""
    val.compile_options & Base.PCRE.CASELESS   != 0 && (opts *= "i")
    val.compile_options & Base.PCRE.MULTILINE  != 0 && (opts *= "m")
    val.compile_options & Base.PCRE.DOTALL     != 0 && (opts *= "s")
    _bson_cstring!(io, opts)
end

_bson_element!(io::IO, key::String, val::Symbol) = _bson_element!(io, key, string(val))
_bson_element!(io::IO, key::String, val::AbstractChar) = _bson_element!(io, key, string(val))
_bson_element!(io::IO, key::String, val::Enum) = _bson_element!(io, key, string(val))
_bson_element!(io::IO, key::String, val::Type) = _bson_element!(io, key, string(val))
_bson_element!(io::IO, key::String, val::Dates.TimeType) = _bson_element!(io, key, string(val))
_bson_element!(io::IO, key::String, val::UUID) = _bson_element!(io, key, string(val))

function _bson_element!(io::IO, key::String, val::AbstractVector{UInt8})
    write(io, BSON_BINARY); _bson_cstring!(io, key)
    write(io, htol(Int32(length(val))))
    write(io, BSON_BIN_GENERIC)
    write(io, val)
end

function _bson_iterable!(io::IO, key::String, iter)
    write(io, BSON_ARRAY); _bson_cstring!(io, key)
    _bson_subdocument!(io) do buf
        for (i, item) in enumerate(iter)
            _bson_element!(buf, string(i - 1), item)
        end
    end
end

_bson_element!(io::IO, key::String, val::AbstractVector) = _bson_iterable!(io, key, val)
_bson_element!(io::IO, key::String, val::Tuple) = _bson_iterable!(io, key, val)
_bson_element!(io::IO, key::String, val::AbstractSet) = _bson_iterable!(io, key, val)

function _bson_element!(io::IO, key::String, val::Pair)
    write(io, BSON_DOCUMENT); _bson_cstring!(io, key)
    _bson_subdocument!(io) do buf
        _bson_element!(buf, string(first(val)), last(val))
    end
end

function _bson_element!(io::IO, key::String, val::AbstractDict)
    write(io, BSON_DOCUMENT); _bson_cstring!(io, key)
    _bson_subdocument!(io) do buf
        for (k, v) in val
            _bson_element!(buf, string(k), v)
        end
    end
end

function _bson_element!(io::IO, key::String, val::NamedTuple)
    write(io, BSON_DOCUMENT); _bson_cstring!(io, key)
    _bson_subdocument!(io) do buf
        for k in keys(val)
            _bson_element!(buf, string(k), val[k])
        end
    end
end

# ── Context-aware serialization ──

function _bson_write_struct!(io::IO, strategy, val::T) where {T}
    N = fieldcount(T)
    Base.@nexprs 32 i -> begin
        if i <= N
            fn_i = fieldnames(T)[i]
            v_i = ser_type(strategy, T, ser_value(strategy, T, Val(fn_i), getfield(val, fn_i)))
            if !ser_skip(strategy, T, Val(fn_i), v_i)
                _bson_element!(io, string(ser_name(strategy, T, Val(fn_i))), v_i)
            end
        end
    end
    if N > 32
        for field in fieldnames(T)[33:end]
            v = ser_type(strategy, T, ser_value(strategy, T, Val(field), getfield(val, field)))
            ser_skip(strategy, T, Val(field), v) && continue
            _bson_element!(io, string(ser_name(strategy, T, Val(field))), v)
        end
    end
end

function _bson_element!(io::IO, key::String, val::T) where {T}
    write(io, BSON_DOCUMENT); _bson_cstring!(io, key)
    _bson_subdocument!(io) do buf
        _bson_write_struct!(buf, DefaultStrategy(), val)
    end
end

"""
    to_bson(data) -> Vector{UInt8}
    to_bson(strategy, data) -> Vector{UInt8}

Serialize `data` into a BSON byte array.

The top-level value is always encoded as a BSON document. Nested structs produce
sub-documents. `Vector{UInt8}` fields are encoded as BSON binary. `DateTime` values
use the BSON datetime type (milliseconds since Unix epoch). `Regex` values are encoded
as BSON regex. `nothing` and `missing` are encoded as BSON null.

Pass a context object `strategy` (e.g. [`CamelCase()`](@ref)) to apply global field-renaming.

All serialization traits ([`Serde.ser_name`](@ref), [`Serde.ser_value`](@ref),
[`Serde.ser_skip`](@ref)) are applied.

# Arguments
- `data`: the value to serialize (struct or `AbstractDict`).
- `strategy`: optional context object.

# Returns
`Vector{UInt8}` — the raw BSON bytes.

# Examples
```julia
julia> struct Point; x::Int; y::Int; end

julia> bytes = to_bson(Point(1, 2));

julia> from_bson(Point, bytes)
Point(1, 2)
```

See also: [`from_bson`](@ref).
"""
function to_bson(strategy, data::AbstractDict)::Vector{UInt8}
    io = IOBuffer()
    try
        _bson_subdocument!(io) do buf
            for (k, v) in data
                _bson_element!(buf, string(k), v)
            end
        end
        return take!(io)
    finally
        close(io)
    end
end

function to_bson(strategy, data::T)::Vector{UInt8} where {T}
    io = IOBuffer()
    try
        _bson_subdocument!(io) do buf
            _bson_write_struct!(buf, strategy, data)
        end
        return take!(io)
    finally
        close(io)
    end
end

to_bson(data) = to_bson(DefaultStrategy(), data)

end
