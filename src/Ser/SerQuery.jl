module SerQuery

export to_query

using ..Serde

function _bytes end
function escape_query end

isnull(::Any)::Bool = false
isnull(v::Missing)::Bool = true
isnull(v::Nothing)::Bool = true

_bytes(s::SubArray{UInt8}) = unsafe_wrap(Array, pointer(s), length(s))
_bytes(s::Union{Vector{UInt8},Base.CodeUnits}) = _bytes(String(s))
_bytes(s::AbstractString) = codeunits(s)
_bytes(s::Vector{UInt8}) = s

utf8_chars(str::AbstractString) = (Char(c) for c in _bytes(str))

function issafe(c::Char)::Bool
    return c == '-' ||
           c == '.' ||
           c == '_' ||
           (isascii(c) && (isletter(c) || isnumeric(c)))
end

escape_query(v::Any) = escape_query(string(v))
escape_query(c::Char) = string('%', uppercase(string(Int(c), base = 16, pad = 2)))
escape_query(bytes::Vector{UInt8}) = bytes

function escape_query(str::AbstractString)
    escaped = String[]
    for c in utf8_chars(str)
        push!(escaped, string(issafe(c) ? c : escape_query(c)))
    end
    return join(escaped)
end

function make_pair(k::String, v::String, escape::Bool = true)::Vector{String}
    return if escape
        [escape_query(k) * "=" * escape_query(v)]
    else
        [k * "=" * v]
    end
end

function ser_pair(
    ::Type{StructType},
    ::Type{ValueType},
    key::String,
    value::ValueType,
)::Tuple{Vector{String},Vector{String}} where {StructType<:Any,ValueType<:Any}
    return ([key], [string(value)])
end

function ser_pair(
    ::Type{StructType},
    ::Type{ValueType},
    key::String,
    value::ValueType,
)::Tuple{Vector{String},Vector{String}} where {StructType<:Any,ValueType<:AbstractVector}
    vals = String[]
    for elem in value
        push!(vals, elem)
    end
    return ([key], ["[" * join(vals, ",") * "]"])
end

function ser_pair(
    ::Type{StructType},
    ::Type{ValueType},
    key::String,
    value::ValueType,
)::Tuple{Vector{String},Vector{String}} where {StructType<:Any,ValueType<:AbstractSet}
    vals = String[]
    for elem in value
        push!(vals, elem)
    end
    return ([key], ["[" * join(vals, ",") * "]"])
end

function iter_query(f::Function, query::AbstractDict)::Nothing
    for (k, v) in query
        f(ser_pair(AbstractDict, typeof(v), string(k), v))
    end
    return nothing
end

(ser_name(::Type{T}, k::Val{x})::Symbol) where {T,x} = Serde.ser_name(T, k)
(ser_value(::Type{T}, k::Val{x}, v::V)) where {T,x,V} = Serde.ser_value(T, k, v)
(ser_type(::Type{T}, v::V)::V) where {T,V} = Serde.ser_type(T, v)

(ser_ignore_field(::Type{T}, k::Val{x})::Bool) where {T,x} = Serde.ser_ignore_field(T, k)
(ser_ignore_field(::Type{T}, k::Val{x}, v::V)::Bool) where {T,x,V} = ser_ignore_field(T, k)
(ser_ignore_null(::Type{T})::Bool) where {T} = true

function iter_query(f::Function, query::Q)::Nothing where {Q}
    for field in fieldnames(Q)
        v = ser_type(Q, ser_value(Q, Val(field), getfield(query, field)))
        if ser_ignore_null(Q) && isnull(v) || ser_ignore_field(Q, Val(field), v)
            continue
        end
        field = string(ser_name(Q, Val(field)))
        f(ser_pair(Q, typeof(v), field, v))
    end
    return nothing
end

"""
    to_query(data; kw...) -> String

Converts dictionary `data` (or custom type) to the query string.
Values of `data` must be of primitive types or a vector of such.
In case of custom data, the names of the query elements are obtained from the field names of `data`.

## Keyword arguments
- `delimiter::AbstractString = "&"`: The separator character between query string elements.
- `sort_keys::Bool = false`: A flag that determines whether the keys should be sorted by lexicographic order.
- `escape::Bool = true`: Option to construct a valid URI-encoded string.

## Examples

```julia-repl
julia> struct Data
           int::Int64
           float::Float64
           strings::Vector{String}
       end

julia> to_query(Data(1, 2.0, ["a", "b", "c"]), sort_keys=true)
"float=2.0&int=1&strings=%5Ba%2Cb%2Cc%5D"

julia> to_query(Data(1, 2.0, ["a", "b", "c"]), escape = false)
"int=1&float=2.0&strings=[a,b,c]"
```

```julia-repl
julia> data = Dict(
           "int" => 1,
           "float" => 2.0,
           "strings" => ["a", "b", "c"]
       );

julia> to_query(data, escape = false)
"int=1&strings=[a,b,c]&float=2.0"
```
"""
function to_query(
    data::T;
    delimiter::AbstractString = "&",
    sort_keys::Bool = false,
    escape::Bool = true,
)::String where {T}
    kv = String[]
    iter_query(
        p -> append!(kv, [make_pair(k, v, escape) for (k, v) in zip(p[1], p[2])]...),
        data,
    )
    return join(sort_keys ? sort!(kv) : kv, delimiter)
end

end
