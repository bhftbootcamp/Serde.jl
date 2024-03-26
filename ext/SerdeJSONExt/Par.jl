module ParJson

using JSON
import Serde

Base.show(io::IO, e::Serde.JSON.JsonSyntaxError) = print(io, e.message)

function Serde.JSON.parse_json(x::S; dict_type::Type{D} = Dict{String,Any}, kw...) where {S<:AbstractString,D<:AbstractDict}
    try
        JSON.parse(x; dicttype = dict_type, kw...)
    catch e
        throw(JsonSyntaxError("invalid JSON syntax", e))
    end
end

function Serde.JSON.parse_json(x::Vector{UInt8}; kw...)
    return parse_json(unsafe_string(pointer(x), length(x)); kw...)
end

end
