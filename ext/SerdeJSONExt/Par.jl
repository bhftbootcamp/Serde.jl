module ParJson

export JsonSyntaxError
export parse_json

using JSON

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

function parse_json(x::S; dict_type::Type{D} = Dict{String,Any}, kw...) where {S<:AbstractString,D<:AbstractDict}
    try
        JSON.parse(x; dicttype = dict_type, kw...)
    catch e
        throw(JsonSyntaxError("invalid JSON syntax", e))
    end
end

function parse_json(x::Vector{UInt8}; kw...)
    return parse_json(unsafe_string(pointer(x), length(x)); kw...)
end

end
