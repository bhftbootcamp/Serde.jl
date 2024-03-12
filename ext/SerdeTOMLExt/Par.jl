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
