module ParJson

export JsonSyntaxError
export parse_json

using YYJSON

"""
    JsonSyntaxError <: Exception

Exception thrown when a [`parse_json`](@ref) fails due to incorrect JSON syntax or any underlying error that occurs during parsing.

## Fields
- `message::String`: The error message.
- `exception::Exception`: The catched exception.
"""
struct JsonSyntaxError <: Exception
    message::String
    exception::Exception
end

Base.show(io::IO, e::JsonSyntaxError) = print(io, e.message)

"""
    parse_json(x::AbstractString; kw...) -> Dict{String,Any}
    parse_json(x::Vector{UInt8}; kw...) -> Dict{String,Any}

Parse a JSON string `x` (or vector of UInt8) into a dictionary.

## Keyword arguments
You can see additional keyword arguments in JSON.jl package [documentation](https://github.com/JuliaIO/JSON.jl?tab=readme-ov-file#documentation).

## Examples

```julia-repl
julia> json = \"\"\"
        {
            "number": 123,
            "vector": [1, 2, 3],
            "dictionary":
            {
                "string": "123"
            }
        }
       \"\"\";

julia> parse_json(json)
Dict{String, Any} with 3 entries:
  "number"     => 123
  "vector"     => Any[1, 2, 3]
  "dictionary" => Dict{String, Any}("string"=>"123")
```
"""
function parse_json end

function parse_json(x::S; dict_type::Type{D} = Dict{String,Any}, kw...) where {S<:AbstractString,D<:AbstractDict}
    try
        YYJSON.parse_json(x; dict_type, kw...)
    catch e
        throw(JsonSyntaxError("invalid JSON syntax", e))
    end
end

function parse_json(x::Vector{UInt8}; kw...)
    return parse_json(unsafe_string(pointer(x), length(x)); kw...)
end

end
