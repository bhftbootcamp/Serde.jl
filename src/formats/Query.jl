module SerdeQuery

export parse_query, from_query, try_from_query, to_query

import ..ParseError, ..SerdeError, ..to_deser, ..DefaultStrategy
import ..ser_name, ..ser_value, ..ser_type, ..ser_skip
import ..isnull, ..parse_value, ..deser_name
import ..ClassType, ..StructClass

# ── Internal utilities ──

function _query_cut(s::AbstractString, sep::AbstractString)
    index = findfirst(sep, s)
    if index !== nothing
        return s[begin:index[1]-1], s[index[1]+length(sep):end]
    else
        return (s, "")
    end
end

function _query_unescape(q::AbstractString)
    q = replace(q, '+' => ' ')
    occursin("%", q) || return q
    io = IOBuffer()
    i = firstindex(q)
    try
        while i <= lastindex(q)
            c = q[i]
            if c == '%'
                i1 = nextind(q, i)
                i2 = nextind(q, i1)
                (i2 > lastindex(q)) && throw(ParseError("Query", "invalid Query escape at end of string", ErrorException("truncated escape")))
                write(io, Base.parse(UInt8, SubString(q, i1, i2); base = 16))
                i = nextind(q, i2)
            else
                write(io, c)
                i = nextind(q, i)
            end
        end
        return String(take!(io))
    catch e
        e isa SerdeError && rethrow(e)
        throw(ParseError("Query", "invalid Query escape sequence", e))
    finally
        close(io)
    end
end

function parse_value(::Type{ST}, ::Type{Union{Nothing,FT}}, value) where {ST,FT}
    return parse_value(ST, FT, value)
end

function parse_value(::Type{ST}, ::Type{Union{Missing,FT}}, value) where {ST,FT}
    return parse_value(ST, FT, value)
end

function parse_value(::Type{ST}, ::Type{FT}, value) where {ST,FT<:Union{AbstractVector,AbstractSet}}
    s = String(value)
    if !isempty(s) && s[1] == '[' && s[end] == ']'
        s = s[2:end-1]
    end
    isempty(s) && return String[]
    return String[String(strip(part)) for part in split(s, ',')]
end

# ── Parsing ──

"""
    parse_query(x::Union{AbstractString, Vector{UInt8}}; dict_type = Dict{String,Any}, delimiter = "&") -> Dict

Parse a URL-encoded query string into a `Dict` without mapping to a target type.

Keys and values are percent-decoded. Repeated keys (e.g. `a=1&a=2`) produce a `Vector`
of values.

# Arguments
- `x`: query string as `String` or `Vector{UInt8}` (leading `?` should be stripped).

# Keyword arguments
- `dict_type::Type{<:AbstractDict}`: concrete dict type (default `Dict{String,Any}`).
- `delimiter::AbstractString = "&"`: pair separator.

# Returns
A dict mapping decoded keys to decoded values (or vectors of values).

# Throws
- [`ParseError`](@ref): if the query string contains invalid percent-encoding or semicolons.

# Examples
```julia
julia> parse_query("name=Alice&age=30")
Dict{String, Any}("name" => "Alice", "age" => "30")

julia> parse_query("color=red&color=blue")
Dict{String, Any}("color" => ["red", "blue"])
```

See also: [`from_query`](@ref), [`try_from_query`](@ref).
"""
function parse_query(
    x::AbstractString;
    dict_type::Type{D} = Dict{String,Any},
    delimiter::AbstractString = "&",
    kw...,
) where {D<:AbstractDict}
    try
        result = D()
        for part in split(x, delimiter)
            raw_key, raw_value = _query_cut(part, "=")
            isempty(raw_key) && continue
            contains(raw_key, ';') && throw(ParseError("Query", "invalid semicolon separator in query key", ErrorException("semicolon")))
            key   = _query_unescape(raw_key)
            value = _query_unescape(raw_value)
            if haskey(result, key)
                push!(result[key], value)
            else
                result[key] = [value]
            end
        end
        for key in keys(result)
            v = result[key]
            result[key] = length(v) == 1 ? only(v) : v
        end
        return result
    catch e
        e isa SerdeError && rethrow(e)
        throw(ParseError("Query", "invalid Query syntax", e))
    end
end

function parse_query(x::Vector{UInt8}; kw...)
    return parse_query(unsafe_string(pointer(x), length(x)); kw...)
end

# ── Deserialization ──

"""
    from_query(::Type{T}, x; kw...) -> T
    from_query(strategy, ::Type{T}, x; kw...) -> T
    from_query(f::Function, x; kw...) -> Any

Parse a URL query string and deserialize it into type `T`.

All values in a query string are strings; the deserialization engine handles type coercion
for each field. Vector/Set fields are populated from repeated keys or bracket notation.

Pass a strategy object (e.g. [`CamelCase()`](@ref)) to apply global field-renaming.

# Arguments
- `::Type{T}`: target type to construct.
- `x`: query string as `String` or `Vector{UInt8}`.
- `strategy`: optional serialization strategy.

# Returns
A value of type `T`.

# Throws
- [`ParseError`](@ref): if `x` contains invalid percent-encoding.
- [`MissingFieldError`](@ref): if a required struct field is absent.
- [`TypeMismatchError`](@ref): if a value cannot be coerced to the field type.

# Examples
```julia
julia> struct Filter; name::String; limit::Int; end

julia> from_query(Filter, "name=Alice&limit=10")
Filter("Alice", 10)
```

See also: [`try_from_query`](@ref), [`to_query`](@ref), [`parse_query`](@ref).
"""
function from_query(strategy, ::Type{T}, x; kw...) where {T}
    dict = parse_query(x; kw...)
    if ClassType(T) isa StructClass && fieldcount(T) > 0
        field_lookup = Dict{Symbol,Tuple{Symbol,Type}}()
        for (i, fn) in enumerate(fieldnames(T))
            ft = fieldtype(T, i)
            field_lookup[fn] = (fn, ft)
            nm = Symbol(deser_name(strategy, T, Val(fn)))
            field_lookup[nm] = (fn, ft)
        end
        for key in collect(keys(dict))
            sym = Symbol(key)
            entry = get(field_lookup, sym, nothing)
            entry === nothing && continue
            _fn, ft = entry
            dict[key] = parse_value(T, ft, dict[key])
        end
    end
    return to_deser(strategy, T, dict)
end

from_query(::Type{T}, x; kw...) where {T} = from_query(DefaultStrategy(), T, x; kw...)
from_query(::Type{Nothing}, _) = nothing
from_query(::Type{Missing}, _) = missing

function from_query(f::Function, x; kw...)
    dict = parse_query(x; kw...)
    return to_deser(f(dict), dict)
end

# ── Error-safe deserialization ──

function _try_wrap(f, args...; kw...)
    try
        return f(args...; kw...)
    catch e
        return e isa SerdeError ? e : ParseError("Query", string(e), e)
    end
end

"""
    try_from_query(::Type{T}, x; kw...) -> Union{T, SerdeError}
    try_from_query(strategy, ::Type{T}, x; kw...) -> Union{T, SerdeError}

Like [`from_query`](@ref) but returns a [`SerdeError`](@ref) instead of throwing on failure.

# Returns
- `T` on success.
- A [`ParseError`](@ref) or [`DeserError`](@ref) subtype on failure.

See also: [`from_query`](@ref), [`SerdeError`](@ref).
"""
try_from_query(::Type{T}, x; kw...)           where {T} = _try_wrap(from_query, T, x; kw...)
try_from_query(strategy, ::Type{T}, x; kw...) where {T} = _try_wrap(from_query, strategy, T, x; kw...)

# ── Serialization ──

@inline function _query_issafe(c::UInt8)
    return (UInt8('A') <= c <= UInt8('Z')) ||
           (UInt8('a') <= c <= UInt8('z')) ||
           (UInt8('0') <= c <= UInt8('9')) ||
           c == UInt8('-') || c == UInt8('.') || c == UInt8('_')
end

const QUERY_HEX = UInt8['0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F']

function _query_escape(io::IO, str::AbstractString)
    for b in codeunits(str)
        if _query_issafe(b)
            write(io, b)
        else
            write(io, UInt8('%'))
            write(io, QUERY_HEX[(b >> 4) + 1])
            write(io, QUERY_HEX[(b & 0x0f) + 1])
        end
    end
end

function _query_write_pair!(io::IO, k::AbstractString, v::AbstractString, escape::Bool, delim::AbstractString, first_entry::Bool)
    first_entry || write(io, delim)
    if escape
        _query_escape(io, k)
        write(io, '=')
        _query_escape(io, v)
    else
        write(io, k)
        write(io, '=')
        write(io, v)
    end
end

_query_format_value(v) = string(v)
_query_format_value(v::Union{AbstractVector,AbstractSet}) = "[" * join(string.(v), ',') * "]"

function _query_collect_pairs!(strategy, pairs::Vector{Tuple{String,String}}, data::AbstractDict)
    for (k, v) in data
        push!(pairs, (string(k), _query_format_value(v)))
    end
end

function _query_collect_pairs!(strategy, pairs::Vector{Tuple{String,String}}, data::T) where {T}
    N = fieldcount(T)
    Base.@nexprs 32 i -> begin
        if i <= N
            fn_i = fieldnames(T)[i]
            v_i = ser_type(strategy, T, ser_value(strategy, T, Val(fn_i), getfield(data, fn_i)))
            if !(isnull(v_i) || ser_skip(strategy, T, Val(fn_i), v_i))
                push!(pairs, (string(ser_name(strategy, T, Val(fn_i))), _query_format_value(v_i)))
            end
        end
    end
    if N > 32
        for field in fieldnames(T)[33:end]
            v = ser_type(strategy, T, ser_value(strategy, T, Val(field), getfield(data, field)))
            (isnull(v) || ser_skip(strategy, T, Val(field), v)) && continue
            push!(pairs, (string(ser_name(strategy, T, Val(field))), _query_format_value(v)))
        end
    end
end

"""
    to_query(data; delimiter = "&", sort_keys = false, escape = true) -> String
    to_query(strategy, data; delimiter = "&", sort_keys = false, escape = true) -> String

Serialize `data` into a URL-encoded query string.

Struct fields and dict keys become query parameter names; values are converted to strings.
`Vector` and `Set` values are serialized in bracket notation (`[v1,v2]`). Null values
(`nothing`, `missing`) and skipped fields are omitted.

Pass a strategy object (e.g. [`CamelCase()`](@ref)) to apply global field-renaming.

All serialization traits ([`Serde.ser_name`](@ref), [`Serde.ser_value`](@ref),
[`Serde.ser_skip`](@ref)) are applied.

# Arguments
- `data`: value to serialize (struct or dict).
- `strategy`: optional serialization strategy.

# Keyword arguments
- `delimiter::AbstractString = "&"`: separator between `key=value` pairs.
- `sort_keys::Bool = false`: sort parameter names lexicographically before output.
- `escape::Bool = true`: percent-encode characters outside the unreserved set.

# Returns
A query string `String` (without a leading `?`).

# Examples
```julia
julia> struct Search; query::String; limit::Int; end

julia> to_query(Search("hello world", 10))
"query=hello%20world&limit=10"

julia> to_query(Search("hello world", 10); escape=false)
"query=hello world&limit=10"

julia> to_query(Search("hello", 10); sort_keys=true)
"limit=10&query=hello"
```

See also: [`from_query`](@ref).
"""
function to_query(
    strategy,
    data;
    delimiter::AbstractString = "&",
    sort_keys::Bool = false,
    escape::Bool = true,
)::String
    pairs = Tuple{String,String}[]
    _query_collect_pairs!(strategy, pairs, data)
    sort_keys && sort!(pairs; by = first)
    io = IOBuffer()
    try
        first_entry = true
        for (k, v) in pairs
            _query_write_pair!(io, k, v, escape, delimiter, first_entry)
            first_entry = false
        end
        return String(take!(io))
    finally
        close(io)
    end
end

to_query(data; kw...) = to_query(DefaultStrategy(), data; kw...)

function to_query(io::IO, data; kw...)
    write(io, to_query(DefaultStrategy(), data; kw...))
    return nothing
end
function to_query(strategy, io::IO, data; kw...)
    write(io, to_query(strategy, data; kw...))
    return nothing
end

end
