module SerdeToml

using Dates
using UUIDs
import TOML

export parse_toml, from_toml, try_from_toml, to_toml

import ..ParseError, ..SerdeError, ..to_deser, ..DefaultStrategy
import ..ser_name, ..ser_value, ..ser_type, ..ser_skip
import ..isnull, ..issimple

"""
    parse_toml(x::Union{AbstractString, Vector{UInt8}}; kw...) -> Dict{String, Any}

Parse a TOML string or byte vector into a `Dict{String,Any}` without mapping to a target type.

Delegates to the standard library `TOML.parse`.

# Arguments
- `x`: TOML text as a `String` or `Vector{UInt8}`.

# Returns
A `Dict{String, Any}` representing the top-level TOML document.

# Throws
- [`ParseError`](@ref): if `x` contains malformed TOML.

# Examples
```julia
julia> parse_toml("host = \\"localhost\\"\\nport = 8080")
Dict{String, Any}("host" => "localhost", "port" => 8080)
```

See also: [`from_toml`](@ref), [`try_from_toml`](@ref).
"""
function parse_toml end

function parse_toml(x::AbstractString; kw...)
    try
        TOML.parse(x; kw...)
    catch e
        throw(ParseError("TOML", "invalid TOML syntax", e))
    end
end

function parse_toml(x::Vector{UInt8}; kw...)
    return parse_toml(unsafe_string(pointer(x), length(x)); kw...)
end

"""
    from_toml(::Type{T}, x; kw...) -> T
    from_toml(strategy, ::Type{T}, x; kw...) -> T
    from_toml(f::Function, x; kw...) -> Any

Parse a TOML string and deserialize it into type `T`.

# Arguments
- `::Type{T}`: target type to construct.
- `x`: TOML text as a `String` or `Vector{UInt8}`.
- `strategy`: optional context object (e.g. [`CamelCase()`](@ref)).
- `f::Function`: function `(parsed_data) -> Type` for dynamic type dispatch.

# Returns
A value of type `T`.

# Throws
- [`ParseError`](@ref): if `x` is malformed TOML.
- [`MissingFieldError`](@ref): if a required struct field is absent.
- [`TypeMismatchError`](@ref): if a value cannot be coerced to the field type.

# Examples
```julia
julia> struct Server; host::String; port::Int; end

julia> from_toml(Server, "host = \\"localhost\\"\\nport = 9000")
Server("localhost", 9000)
```

See also: [`try_from_toml`](@ref), [`to_toml`](@ref), [`parse_toml`](@ref).
"""
function from_toml(strategy, ::Type{T}, x; kw...) where {T}
    return to_deser(strategy, T, parse_toml(x; kw...))
end

from_toml(::Type{T}, x; kw...) where {T} = from_toml(DefaultStrategy(), T, x; kw...)
from_toml(::Type{Nothing}, _) = nothing
from_toml(::Type{Missing}, _) = missing

function from_toml(f::Function, x; kw...)
    object = parse_toml(x; kw...)
    return to_deser(f(object), object)
end

# ── Error-safe deserialization ──

function _try_wrap(f, args...; kw...)
    try
        return f(args...; kw...)
    catch e
        return e isa SerdeError ? e : ParseError("TOML", string(e), e)
    end
end

"""
    try_from_toml(::Type{T}, x; kw...) -> Union{T, SerdeError}
    try_from_toml(strategy, ::Type{T}, x; kw...) -> Union{T, SerdeError}

Like [`from_toml`](@ref) but returns a [`SerdeError`](@ref) instead of throwing on failure.

# Returns
- `T` on success.
- A [`ParseError`](@ref) or [`DeserError`](@ref) subtype on failure.

See also: [`from_toml`](@ref), [`SerdeError`](@ref).
"""
try_from_toml(::Type{T}, x; kw...)           where {T} = _try_wrap(from_toml, T, x; kw...)
try_from_toml(strategy, ::Type{T}, x; kw...) where {T} = _try_wrap(from_toml, strategy, T, x; kw...)

const TOML_DQUOTE = '"'
const TOML_FLOAT_BUF = Vector{UInt8}(undef, 32)

@inline function _toml_write_uint!(io::IO, n::UInt64)
    n >= 10 && _toml_write_uint!(io, div(n, 10))
    write(io, UInt8('0') + rem(n, 10) % UInt8)
end

_toml_value(io::IO, val::AbstractString; _...) = (print(io, TOML_DQUOTE); escape_string(io, val); print(io, TOML_DQUOTE))
_toml_value(io::IO, val::Symbol; kw...) = _toml_value(io, string(val); kw...)
_toml_value(io::IO, val::AbstractChar; kw...) = _toml_value(io, string(val); kw...)
_toml_value(io::IO, val::Bool; _...) = print(io, val ? "true" : "false")
function _toml_value(io::IO, val::Integer; _...)
    if val < 0
        write(io, UInt8('-'))
        _toml_write_uint!(io, unsigned(-val))
    else
        _toml_write_uint!(io, unsigned(val))
    end
end

function _toml_value(io::IO, val::AbstractFloat; _...)
    if isnan(val)
        write(io, "nan")
    else
        n = Base.Ryu.writeshortest(TOML_FLOAT_BUF, 1, Float64(val))
        unsafe_write(io, pointer(TOML_FLOAT_BUF), n - 1)
    end
end

_toml_value(io::IO, val::Number; _...) = print(io, isnan(val) ? "nan" : val)
_toml_value(io::IO, val::Enum; kw...) = _toml_value(io, string(val); kw...)
_toml_value(io::IO, val::Type; kw...) = _toml_value(io, string(val); kw...)
_toml_value(io::IO, val::Dates.TimeType; kw...) = _toml_value(io, string(val); kw...)
_toml_value(io::IO, val::Dates.DateTime; _...) = print(io, Dates.format(val, Dates.dateformat"YYYY-mm-dd\THH:MM:SS.sss\Z"))
_toml_value(io::IO, val::Dates.Time; _...) = print(io, Dates.format(val, Dates.dateformat"HH:MM:SS.sss"))
_toml_value(io::IO, val::Dates.Date; _...) = print(io, Dates.format(val, Dates.dateformat"YYYY-mm-dd"))
_toml_value(io::IO, val::UUID; kw...) = _toml_value(io, string(val); kw...)

function _toml_key_valid(val::AbstractString)
    return all(c -> isletter(c) || isdigit(c) || c == '-' || c == '_', val)
end

function _toml_key(io::IO, val::AbstractString; _...)
    if _toml_key_valid(val)
        print(io, val)
    else
        print(io, TOML_DQUOTE)
        escape_string(io, val)
        print(io, TOML_DQUOTE)
    end
end

function _toml_key(io::IO, val::Integer; _...)
    if val < 0
        write(io, UInt8('-'))
        _toml_write_uint!(io, unsigned(-val))
    else
        _toml_write_uint!(io, unsigned(val))
    end
end
_toml_key(io::IO, val::Bool; _...) = print(io, val ? "true" : "false")
_toml_key(io::IO, val::AbstractChar; kw...) = _toml_key(io, string(val); kw...)
_toml_key(io::IO, val::Symbol; kw...) = _toml_key(io, string(val); kw...)

function _toml_key_str(val)::String
    io = IOBuffer()
    _toml_key(io, val)
    return String(take!(io))
end

@inline function _toml_indent!(io::IO, level::Int)
    for _ in 1:level
        print(io, "  ")
    end
end

function _toml_pair!(io::IO, key, val::T; parent_key::String = "", level::Int = 0, kw...) where {T}
    key_str = isempty(parent_key) ? _toml_key_str(key) : parent_key * "." * _toml_key_str(key)
    print(io, '\n')
    _toml_indent!(io, level + 1)
    print(io, '[', key_str, "]\n")
    _to_toml!(io, get(kw, :strategy, DefaultStrategy()), val; parent_key = key_str, level = level + 1, kw...)
end

function _toml_pair_simple!(io::IO, key, val; level::Int = 0, kw...)
    _toml_indent!(io, level)
    _toml_key(io, key)
    print(io, " = ")
    _toml_value(io, val)
    print(io, '\n')
end

for ST in (AbstractString, Symbol, Number, Dates.TimeType, UUID)
    @eval function _toml_pair!(io::IO, key, val::$ST; level::Int = 0, kw...)
        _toml_pair_simple!(io, key, val; level, kw...)
    end
end

function _toml_pair!(io::IO, key, val::AbstractVector; level::Int = 0, kw...)
    if isempty(val)
        _toml_indent!(io, level)
        _toml_key(io, key)
        print(io, " = []\n")
    elseif issimple(val[1])
        _toml_indent!(io, level)
        _toml_key(io, key)
        print(io, " = [")
        for (i, v) in enumerate(val)
            i > 1 && print(io, ',')
            _toml_value(io, v)
        end
        print(io, "]\n")
    else
        parent_key = get(kw, :parent_key, "")
        key_str = isempty(parent_key) ? _toml_key_str(key) : parent_key * "." * _toml_key_str(key)
        for v in val
            print(io, '\n')
            _toml_indent!(io, level + 1)
            print(io, "[[", key_str, "]]\n")
            for (k, vv) in _toml_pairs(get(kw, :strategy, DefaultStrategy()), v; kw...)
                _toml_pair!(io, k, vv; parent_key = key_str, level = level + 1, kw...)
            end
        end
    end
end

function _toml_pairs(strategy, val::AbstractDict; kw...)
    return sort([(k, v) for (k, v) in val], by = x -> !issimple(x[2]))
end

function _toml_pairs(strategy, val::T; kw...) where {T}
    kv = Tuple[]
    N = fieldcount(T)
    Base.@nexprs 32 i -> begin
        if i <= N
            fn_i = fieldnames(T)[i]
            k_i = ser_name(strategy, T, Val(fn_i))
            v_i = ser_type(strategy, T, ser_value(strategy, T, Val(fn_i), getfield(val, fn_i)))
            if !(isnull(v_i) || ser_skip(strategy, T, Val(fn_i), v_i))
                push!(kv, (k_i, v_i))
            end
        end
    end
    if N > 32
        for field in fieldnames(T)[33:end]
            k = ser_name(strategy, T, Val(field))
            v = ser_type(strategy, T, ser_value(strategy, T, Val(field), getfield(val, field)))
            (isnull(v) || ser_skip(strategy, T, Val(field), v)) && continue
            push!(kv, (k, v))
        end
    end
    return sort(kv, by = x -> !issimple(x[2]))
end

# ── Context-aware serialization ──

function _to_toml!(io::IO, strategy, data::T; kw...) where {T}
    for (k, v) in _toml_pairs(strategy, data; kw...)
        _toml_pair!(io, k, v; strategy = strategy, kw...)
    end
end

"""
    to_toml(data; kw...) -> String
    to_toml(strategy, data; kw...) -> String

Serialize `data` into a TOML string.

Struct fields, dicts, and arrays are mapped to TOML sections, tables, and arrays of tables
following TOML conventions. Scalar fields are written as inline key-value pairs; nested
structs produce `[section]` headers.

Pass a context object `strategy` (e.g. [`CamelCase()`](@ref)) as the first argument to apply
global field-renaming.

All serialization traits ([`Serde.ser_name`](@ref), [`Serde.ser_value`](@ref),
[`Serde.ser_skip`](@ref)) are applied. Null values (`nothing`, `missing`) are omitted.

# Arguments
- `data`: value to serialize (struct or dict).
- `strategy`: optional context object.

# Returns
A TOML-formatted `String`.

# Examples
```julia
julia> struct Server; host::String; port::Int; end

julia> to_toml(Server("localhost", 8080)) |> print
host = "localhost"
port = 8080
```

See also: [`from_toml`](@ref).
"""
function to_toml(strategy, data::T; kw...)::String where {T}
    io = IOBuffer()
    try
        _to_toml!(io, strategy, data; kw...)
        return String(take!(io))
    finally
        close(io)
    end
end

to_toml(data; kw...) = to_toml(DefaultStrategy(), data; kw...)

end
