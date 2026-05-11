module SerdeYaml

using Dates
using UUIDs
using YAML

export parse_yaml, from_yaml, try_from_yaml, to_yaml

import ..ParseError, ..SerdeError, ..to_deser, ..DefaultStrategy
import ..ser_name, ..ser_value, ..ser_type, ..ser_skip

"""
    parse_yaml(x::Union{AbstractString, Vector{UInt8}}; dict_type = Dict{String,Any}, kw...) -> Any

Parse a YAML string or byte vector into Julia data structures without mapping to a target type.

Returns the raw parsed value: a `Dict{String,Any}` for YAML mappings, a `Vector{Any}` for
sequences, or a scalar for plain values. Delegates to the `YAML.jl` library internally.

# Arguments
- `x`: YAML text as a `String` or `Vector{UInt8}`.

# Keyword arguments
- `dict_type::Type{<:AbstractDict}`: concrete dict type for YAML mappings (default `Dict{String,Any}`).
- Additional keyword arguments are forwarded to `YAML.load`.

# Returns
The parsed Julia value.

# Throws
- [`ParseError`](@ref): if `x` contains malformed YAML.

# Examples
```julia
julia> parse_yaml("x: 1\\ny: 2")
Dict{String, Any}("x" => 1, "y" => 2)
```

See also: [`from_yaml`](@ref), [`try_from_yaml`](@ref).
"""
function parse_yaml end

function parse_yaml(x::AbstractString; dict_type::Type{D} = Dict{String,Any}, kw...) where {D<:AbstractDict}
    try
        YAML.load(x; dicttype = dict_type, kw...)
    catch e
        throw(ParseError("YAML", "invalid YAML syntax", e))
    end
end

function parse_yaml(x::Vector{UInt8}; kw...)
    return parse_yaml(unsafe_string(pointer(x), length(x)); kw...)
end

"""
    from_yaml(::Type{T}, x; kw...) -> T
    from_yaml(strategy, ::Type{T}, x; kw...) -> T
    from_yaml(f::Function, x; kw...) -> Any

Parse a YAML string and deserialize it into type `T`.

When called with a function `f`, the raw parsed value is passed to `f` to determine the
target type dynamically: `to_deser(f(parsed), parsed)`.

Pass a context object `strategy` (e.g. [`CamelCase()`](@ref)) as the first argument to apply
global field-renaming during deserialization.

# Arguments
- `::Type{T}`: target type to construct.
- `x`: YAML text as a `String` or `Vector{UInt8}`.
- `strategy`: optional context object.

# Returns
A value of type `T`.

# Throws
- [`ParseError`](@ref): if `x` is malformed YAML.
- [`MissingFieldError`](@ref): if a required struct field is absent.
- [`TypeMismatchError`](@ref): if a value cannot be coerced to the field type.

# Examples
```julia
julia> struct Point; x::Int; y::Int; end

julia> from_yaml(Point, "x: 1\\ny: 2")
Point(1, 2)
```

See also: [`try_from_yaml`](@ref), [`to_yaml`](@ref), [`parse_yaml`](@ref).
"""
function from_yaml(strategy, ::Type{T}, x; kw...) where {T}
    return to_deser(strategy, T, parse_yaml(x; kw...))
end

from_yaml(::Type{T}, x; kw...) where {T} = from_yaml(DefaultStrategy(), T, x; kw...)
from_yaml(::Type{Nothing}, _) = nothing
from_yaml(::Type{Missing}, _) = missing

function from_yaml(f::Function, x; kw...)
    object = parse_yaml(x; kw...)
    return to_deser(f(object), object)
end

function _try_wrap(f, args...; kw...)
    try
        return f(args...; kw...)
    catch e
        return e isa SerdeError ? e : ParseError("YAML", string(e), e)
    end
end

"""
    try_from_yaml(::Type{T}, x; kw...) -> Union{T, SerdeError}
    try_from_yaml(strategy, ::Type{T}, x; kw...) -> Union{T, SerdeError}

Like [`from_yaml`](@ref) but returns a [`SerdeError`](@ref) instead of throwing on failure.

# Returns
- `T` on success.
- A [`ParseError`](@ref) or [`DeserError`](@ref) subtype on failure.

# Examples
```julia
julia> struct Point; x::Int; y::Int; end

julia> try_from_yaml(Point, "x: 1\\ny: 2")
Point(1, 2)

julia> try_from_yaml(Point, ": invalid yaml :") isa SerdeError
true
```

See also: [`from_yaml`](@ref), [`SerdeError`](@ref).
"""
try_from_yaml(::Type{T}, x; kw...)           where {T} = _try_wrap(from_yaml, T, x; kw...)
try_from_yaml(strategy, ::Type{T}, x; kw...) where {T} = _try_wrap(from_yaml, strategy, T, x; kw...)

const YAML_NULL = "null"
const YAML_ESCAPE_CHARS = Set(['"', '\\', '\b', '\f', '\n', '\r', '\t'])

const YAML_INDICATOR_CHARS = Set([':', '#', '?', '-', '[', ']', '{', '}', ',',
                                  '&', '*', '!', '|', '>', '\'', '%', '@', '`'])

@inline function _yaml_indent!(io::IO, l::Int)
    print(io, '\n')
    for _ in 1:l
        print(io, "  ")
    end
end

function _yaml_escape_str!(io::IO, s::AbstractString)
    @inbounds for c in s
        if c == '"'
            write(io, "\\\"")
        elseif c == '\\'
            write(io, "\\\\")
        elseif c == '\0'
            write(io, "\\0")
        elseif c == '\b'
            write(io, "\\b")
        elseif c == '\t'
            write(io, "\\t")
        elseif c == '\n'
            write(io, "\\n")
        elseif c == '\f'
            write(io, "\\f")
        elseif c == '\r'
            write(io, "\\r")
        elseif iscntrl(c)
            cp = Int(c)
            if cp <= 0xff
                write(io, "\\x")
                for shift in (4, 0)
                    d = (cp >> shift) & 0xf
                    write(io, UInt8(d < 10 ? UInt8('0') + d : UInt8('a') + d - 10))
                end
            else
                write(io, "\\u")
                for shift in (12, 8, 4, 0)
                    d = (cp >> shift) & 0xf
                    write(io, UInt8(d < 10 ? UInt8('0') + d : UInt8('a') + d - 10))
                end
            end
        else
            print(io, c)
        end
    end
end

@inline function _yaml_needs_indent(v)
    return v isa Pair || v isa AbstractDict || v isa AbstractVector ||
           v isa Tuple || v isa NamedTuple || v isa AbstractSet
end

function _yaml_needs_quote(s::AbstractString)
    isempty(s) && return true
    # Trim-sensitive chars
    (first(s) in (' ', '\t')) && return true
    (last(s)  in (' ', '\t')) && return true
    for c in s
        if c in YAML_ESCAPE_CHARS || iscntrl(c) || c in YAML_INDICATOR_CHARS
            return true
        end
    end
    # Reserved literals — quoting prevents the parser from interpreting them.
    sl = lowercase(s)
    sl in ("true", "false", "yes", "no", "on", "off", "null", "~") && return true
    # Looks like a number?
    tryparse(Int, s) === nothing || return true
    tryparse(Float64, s) === nothing || return true
    return false
end

# ── Context-aware serialization ──

_yaml_value!(io::IO, strategy, f::Function, val::AbstractString; kw...) = begin
    is_key = get(kw, :is_key, false)
    if any(c -> c in YAML_ESCAPE_CHARS || iscntrl(c), val)
        print(io, '"')
        _yaml_escape_str!(io, val)
        print(io, '"')
    elseif is_key
        if _yaml_needs_quote(val)
            print(io, '"'); _yaml_escape_str!(io, val); print(io, '"')
        else
            print(io, val)
        end
    else
        print(io, '"'); _yaml_escape_str!(io, val); print(io, '"')
    end
end

_yaml_value!(io::IO, strategy, f::Function, val::Symbol; kw...)           = _yaml_value!(io, strategy, f, string(val); kw...)
_yaml_value!(io::IO, strategy, f::Function, val::Dates.TimeType; kw...)   = _yaml_value!(io, strategy, f, string(val); kw...)
_yaml_value!(io::IO, strategy, f::Function, val::UUID; kw...)             = _yaml_value!(io, strategy, f, string(val); kw...)
_yaml_value!(io::IO, strategy, f::Function, val::AbstractChar; kw...)     = print(io, '\'', val, '\'')
_yaml_value!(io::IO, strategy, f::Function, val::Bool; kw...)             = print(io, val)

function _yaml_value!(io::IO, strategy, f::Function, val::Number; kw...)
    isnan(val) ? print(io, ".nan") : isinf(val) ? print(io, ".inf") : print(io, val)
end

_yaml_value!(io::IO, strategy, f::Function, val::Enum; kw...)    = print(io, val)
_yaml_value!(io::IO, strategy, f::Function, val::Missing; kw...) = print(io, YAML_NULL)
_yaml_value!(io::IO, strategy, f::Function, val::Nothing; kw...) = print(io, YAML_NULL)
_yaml_value!(io::IO, strategy, f::Function, val::Type; kw...)    = print(io, val)

@inline _yaml_passthrough_kw(kw) = Base.structdiff(values(kw), NamedTuple{(:is_key, :skip_lf)})

function _yaml_value!(io::IO, strategy, f::Function, val::Pair; l::Int, skip_lf::Bool = false, kw...)
    skip_lf || _yaml_indent!(io, l)
    pass = _yaml_passthrough_kw(kw)
    _yaml_value!(io, strategy, f, first(val); l = l + 1, is_key = true, pass...)
    print(io, ": ")
    _yaml_value!(io, strategy, f, last(val); l = l + 1, pass...)
end

function _yaml_value!(io::IO, strategy, f::Function, val::AbstractDict; l::Int, skip_lf::Bool = false, kw...)
    skip_lf || _yaml_indent!(io, l)
    pass = _yaml_passthrough_kw(kw)
    first_entry = true
    for (k, v) in val
        first_entry || _yaml_indent!(io, l)
        first_entry = false
        _yaml_value!(io, strategy, f, k; l = l + 1, is_key = true, pass...)
        print(io, _yaml_needs_indent(v) ? ":" : ": ")
        _yaml_value!(io, strategy, f, v; l = l + 1, pass...)
    end
end

function _yaml_iterable!(io::IO, strategy, f::Function, iter; l::Int, skip_lf::Bool = false, kw...)
    skip_lf || _yaml_indent!(io, l)
    pass = _yaml_passthrough_kw(kw)
    first_entry = true
    for item in iter
        first_entry || _yaml_indent!(io, l)
        first_entry = false
        print(io, "- ")
        _yaml_value!(io, strategy, f, item; l = l + 1, skip_lf = true, pass...)
    end
end

_yaml_value!(io::IO, strategy, f::Function, val::AbstractVector; l::Int, kw...) = _yaml_iterable!(io, strategy, f, val; l, kw...)
_yaml_value!(io::IO, strategy, f::Function, val::Tuple; l::Int, kw...)          = _yaml_iterable!(io, strategy, f, val; l, kw...)
_yaml_value!(io::IO, strategy, f::Function, val::AbstractSet; l::Int, kw...)    = _yaml_iterable!(io, strategy, f, val; l, kw...)

function _yaml_value!(io::IO, strategy, f::Function, val::NamedTuple; l::Int, skip_lf::Bool = false, kw...)
    skip_lf || _yaml_indent!(io, l)
    pass = _yaml_passthrough_kw(kw)
    first_entry = true
    for k in keys(val)
        first_entry || _yaml_indent!(io, l)
        first_entry = false
        _yaml_value!(io, strategy, f, k; l = l + 1, is_key = true, pass...)
        print(io, ": ")
        _yaml_value!(io, strategy, f, val[k]; l = l + 1, skip_lf = true, pass...)
    end
end

function _yaml_value!(io::IO, strategy, f::Function, val::T; l::Int, skip_lf::Bool = false, kw...) where {T}
    skip_lf || _yaml_indent!(io, l)
    pass = _yaml_passthrough_kw(kw)
    _first = true
    N = fieldcount(T)
    if N == 0
        print(io, "{}")
        return
    end
    if f === fieldnames
        Base.@nexprs 32 i -> begin
            if i <= N
                fn_i = fieldnames(T)[i]
                k_i = ser_name(strategy, T, Val(fn_i))
                v_i = ser_type(strategy, T, ser_value(strategy, T, Val(fn_i), getfield(val, fn_i)))
                if !ser_skip(strategy, T, Val(fn_i), v_i)
                    _first || _yaml_indent!(io, l)
                    _first = false
                    _yaml_value!(io, strategy, f, k_i; l = l + 1, is_key = true, pass...)
                    print(io, _yaml_needs_indent(v_i) ? ":" : ": ")
                    _yaml_value!(io, strategy, f, v_i; l = l + 1, pass...)
                end
            end
        end
        if N > 32
            for field in fieldnames(T)[33:end]
                k = ser_name(strategy, T, Val(field))
                v = ser_type(strategy, T, ser_value(strategy, T, Val(field), getfield(val, field)))
                ser_skip(strategy, T, Val(field), v) && continue
                _first || _yaml_indent!(io, l)
                _first = false
                _yaml_value!(io, strategy, f, k; l = l + 1, is_key = true, pass...)
                print(io, _yaml_needs_indent(v) ? ":" : ": ")
                _yaml_value!(io, strategy, f, v; l = l + 1, pass...)
            end
        end
    else
        for field in f(T)
            k = ser_name(strategy, T, Val(field))
            v = ser_type(strategy, T, ser_value(strategy, T, Val(field), getfield(val, field)))
            ser_skip(strategy, T, Val(field), v) && continue
            _first || _yaml_indent!(io, l)
            _first = false
            _yaml_value!(io, strategy, f, k; l = l + 1, is_key = true, pass...)
            print(io, _yaml_needs_indent(v) ? ":" : ": ")
            _yaml_value!(io, strategy, f, v; l = l + 1, pass...)
        end
    end
end

"""
    to_yaml(data) -> String
    to_yaml(strategy, data) -> String

Serialize `data` into a YAML string.

All serialization traits ([`Serde.ser_name`](@ref), [`Serde.ser_value`](@ref),
[`Serde.ser_type`](@ref), [`Serde.ser_skip`](@ref)) are applied.

Pass a context object `strategy` (e.g. [`CamelCase()`](@ref)) as the first argument to apply
global field-renaming.

# Arguments
- `data`: the value to serialize.
- `strategy`: optional context object.

# Returns
A YAML `String`.

# Examples
```julia
julia> struct Server; host::String; port::Int; end

julia> to_yaml(CamelCase(), Server("localhost", 8080)) |> print
host: "localhost"
port: 8080
```

See also: [`from_yaml`](@ref).
"""
function to_yaml(strategy, data; kw...)::String
    io = IOBuffer()
    try
        _yaml_value!(io, strategy, fieldnames, data; l = 0, skip_lf = true, kw...)
        print(io, "\n")
        return String(take!(io))
    finally
        close(io)
    end
end

to_yaml(data; kw...) = to_yaml(DefaultStrategy(), data; kw...)

function to_yaml(io::IO, data; kw...)
    _yaml_value!(io, DefaultStrategy(), fieldnames, data; l = 0, skip_lf = true, kw...)
    print(io, "\n")
    return nothing
end
function to_yaml(io::IO, strategy, data; kw...)
    _yaml_value!(io, strategy, fieldnames, data; l = 0, skip_lf = true, kw...)
    print(io, "\n")
    return nothing
end

end
