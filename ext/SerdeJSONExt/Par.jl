module ParJson

using JSON
import Serde

Base.show(io::IO, e::Serde.JSON.JsonSyntaxError) = print(io, e.message)

function Serde.parse(::Val{:JSON}, x::S; dict_type::Type{D} = Dict{String,Any}, kw...) where {S<:AbstractString,D<:AbstractDict}
    try
        JSON.parse(x; dicttype = dict_type, kw...)
    catch e
        throw(Serde.JSON.JsonSyntaxError("invalid JSON syntax", e))
    end
end

function Serde.parse(::Val{:JSON}, x::Vector{UInt8}; kw...)
    return Serde.parse(unsafe_string(pointer(x), length(x)); kw...)
end

end
