module ParYaml

export YamlSyntaxError
export parse_yaml

using YAML

"""
    YamlSyntaxError <: Exception

Exception thrown when a [`parse_yaml`](@ref) fails due to incorrect YAML syntax or any underlying error that occurs during parsing.

## Fields
- `message::String`: The error message.
- `exception::Exception`: The catched exception.
"""
struct YamlSyntaxError <: Exception
    message::String
    exception::YAML.ParserError
end

Base.show(io::IO, e::YamlSyntaxError) = print(io, e.message)

function parse_yaml(x::S; dict_type::Type{D} = Dict{String,Any}, kw...) where {S<:AbstractString,D<:AbstractDict}
    try
        YAML.load(x; dicttype = dict_type, kw...)
    catch e
        throw(YamlSyntaxError("invalid YAML syntax", e))
    end
end

function parse_yaml(x::Vector{UInt8}; kw...)
    return parse_yaml(unsafe_string(pointer(x), length(x)); kw...)
end

end
