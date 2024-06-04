module Query

import ..Serde, ..if_module

export to_query,
    deser_query,
    parse_query

const EXT = Val(:Serde_Query)

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
function to_query(args...; kvargs...)
    Serde.to_string(EXT, args...; kvargs...)
end

"""
    deser_query(::Type{T}, x; kw...) -> T

Creates a new object of type `T` and fill it with values from Query formated string `x` (or vector of UInt8).

Keyword arguments `kw` is the same as in [`parse_query`](@ref).

## Examples
```julia-repl
julia> struct Person
           age::Int64
           name::String
           pets::Vector{String}
       end

julia> query = "age=20&name=Nancy&pets=[Cat,Dog]";

julia> deser_query(Person, query)
Person(20, "Nancy", ["Cat", "Dog"])
```
"""
function deser_query(args...; kvargs...)
    Serde.from_string(EXT, args...; kvargs...)
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
function parse_query(args...; kvargs...)
    Serde.parse(EXT, args...; kvargs...)
end

include("Par.jl")
using .ParQuery

include("De.jl")
using .DeQuery

include("Ser.jl")
using .SerQuery

end
