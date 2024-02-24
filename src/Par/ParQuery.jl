module ParQuery

export QuerySyntaxError
export parse_query

"""
    QuerySyntaxError <: Exception

Exception thrown when a [`parse_query`](@ref) fails due to incorrect query syntax or any underlying error that occurs during parsing.

## Fields
- `message::String`: The error message.
- `exception::Exception`: The caught exception.
"""
struct QuerySyntaxError <: Exception
    message::String
    exception::Exception
end

struct QueryParsingError <: Exception
    message::String
end

struct EscapeError <: Exception
    message::String
end

Base.show(io::IO, e::QuerySyntaxError) = print(io, e.message)
Base.show(io::IO, e::QueryParsingError) = print(io, e.message)
Base.show(io::IO, e::EscapeError) = print(io, e.message)

function cut(s::AbstractString, sep::AbstractString)
    index = findfirst(sep, s)
    return if !isnothing(index)
        s[begin:index[1]-1], s[index[1]+length(sep):end]
    else
        (s, "")
    end
end

function unescape(q::AbstractString)::AbstractString
    q = replace(q, '+' => ' ')
    occursin("%", q) || return q
    out = IOBuffer()
    io = IOBuffer(q)
    while !eof(io)
        c = read(io, Char)
        if c == '%'
            c1 = ""
            c = ""
            # Convert a pair of characters (c1, c) representing a hexadecimal value into its corresponding UInt8 value
            # and write it to the specified output stream 'out'.
            # The 'base=16' argument indicates that the conversion should be performed in base 16 (hexadecimal).
            try
                c1 = read(io, Char)
                c = read(io, Char)
                write(out, Base.parse(UInt8, string(c1, c); base = 16))
            catch
                throw(EscapeError("invalid Query escape '%$c1$c'"))
            end
        else
            write(out, c)
        end
    end
    return String(take!(out))
end

function decode_key(k::AbstractString)::AbstractString
    return try
        unescape(k)
    catch e
        throw(e)
    end
end

function validate_key(k::AbstractString)::Nothing
    contains(k, ';') && throw(QueryParsingError("invalid semicolon separator in query key"))
    return nothing
end

function decode_value(v::AbstractString)::AbstractString
    return try
        unescape(v)
    catch e
        throw(e)
    end
end

function parse_value(
    ::Type{StructType},
    ::Type{Union{Nothing,FieldType}},
    value::D,
) where {StructType<:Any,FieldType<:Any,D<:Any}
    return parse_value(StructType, FieldType, value)
end

function parse_value(
    ::Type{StructType},
    ::Type{Union{Missing,FieldType}},
    value::D,
) where {StructType<:Any,FieldType<:Any,D<:Any}
    return parse_value(StructType, FieldType, value)
end

function parse_value(::Type{StructType}, ::Type{FieldType}, value::D) where {StructType<:Any,FieldType<:Any,D<:Any}
    return value
end

function parse_value(
    ::Type{StructType},
    ::Type{FieldType},
    value::D,
) where {StructType<:Any,FieldType<:AbstractVector,D<:Any}
    return String.([m.match for m in eachmatch(r"[^\s\[\],]+", value)])
end

function parse_value(
    ::Type{StructType},
    ::Type{FieldType},
    value::D,
) where {StructType<:Any,FieldType<:AbstractSet,D<:Any}
    return String.([m.match for m in eachmatch(r"[^\s\[\],]+", value)])
end

function parse(
    query::AbstractString;
    delimiter::AbstractString = "&",
    dict_type::Type{D} = Dict{String,Any},
) where {D<:AbstractDict}
    parts = split(query, delimiter)
    parsed = D()
    for part in parts
        key, value = cut(part, "=")
        if isempty(key)
            continue
        end
        key = decode_key(key)
        validate_key(key)
        value = decode_value(value)
        if haskey(parsed, key)
            push!(parsed[key], value)
        else
            parsed[key] = [value]
        end
    end
    return parsed
end

"""
    parse_query(x::AbstractString; kw...) -> Dict{String, Union{String, Vector{String}}}
    parse_query(x::Vector{UInt8}; kw...) -> Dict{String, Union{String, Vector{String}}}

Parses a query string `x` (or vector of UInt8) into a dictionary.

## Keyword arguments
- `backbone::Type = Nothing`: The custom type that describes types of query elements.
- `delimiter::AbstractString = "&"`: The delimiter of query string.
- `dict_type::Type{<:AbstractDict} = Dict`: The type of the dictionary to be returned.

## Examples
```julia-repl
julia> struct Template
           vector::Vector
           value::String
       end

julia> query = "value=abc&vector=[1,2,3]"

julia> parse_query(query)
Dict{String, Union{String, Vector{String}}} with 2 entries:
  "vector" => "[1,2,3]"
  "value"  => "abc"

julia> parse_query(query, backbone = Template)
Dict{String, Union{String, Vector{String}}} with 2 entries:
  "vector" => ["1", "2", "3"]
  "value"  => "abc"
```
"""
function parse_query end

function parse_query(
    x::S;
    backbone::Type = Nothing,
    dict_type::Type{D} = Dict{String,Any},
    kw...,
) where {S<:AbstractString,D<:AbstractDict}
    return try
        parsed = ParQuery.parse(x; dict_type = dict_type, kw...)
        for (key, value) in parsed
            value = length(value) == 1 ? value[begin] : value
            if backbone != Nothing
                value = parse_value(backbone, fieldtype(backbone, Symbol(key)), value)
            end
            parsed[key] = value
        end
        parsed
    catch e
        throw(QuerySyntaxError("invalid Query syntax", e))
    end
end

function parse_query(x::Vector{UInt8}; kw...)
    return parse_query(unsafe_string(pointer(x), length(x)); kw...)
end

end
