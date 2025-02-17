module ParToml

export TomlSyntaxError
export parse_toml

using TOML

"""
    TomlSyntaxError <: Exception

Exception thrown when a [`parse_toml`](@ref) fails due to incorrect TOML syntax or any underlying error that occurs during parsing.

## Fields
- `message::String`: The error message.
- `exception::Exception`: The catched exception.
"""
struct TomlSyntaxError <: Exception
    message::String
    exception::Exception
end

Base.show(io::IO, e::TomlSyntaxError) = print(io, e.message)

"""
    parse_toml(x::AbstractString) -> Dict{String,Any}
    parse_toml(x::Vector{UInt8}) -> Dict{String,Any}

Parses a TOML string `x` (or vector of UInt8) into a dictionary.

## Examples

```julia-repl
julia> toml = \"\"\"
       tag = "line"
       [[points]]
       x = 1
       y = 0
       [[points]]
       x = 2
       y = 3
       \"\"\";

julia> parse_toml(toml)
Dict{String, Any} with 3 entries:
  "tag"  => "line"
  "points" => Any[Dict{String, Any}("y"=>0, "x"=>1), Dict{String, Any}("y"=>3, "x"=>2)]
```
"""
function parse_toml end

function parse_toml(x::S; kw...) where {S<:AbstractString}
    try
        TOML.parse(x; kw...)
    catch e
        throw(TomlSyntaxError("invalid TOML syntax", e))
    end
end

function parse_toml(x::Vector{UInt8}; kw...)
    return parse_toml(unsafe_string(pointer(x), length(x)); kw...)
end

end
