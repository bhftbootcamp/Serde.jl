module ParYaml

using YAML
import Serde

Base.show(io::IO, e::Serde.YAML.YamlSyntaxError) = print(io, e.message)

function Serde.YAML.parse_yaml(x::S; dict_type::Type{D} = Dict{String,Any}, kw...) where {S<:AbstractString,D<:AbstractDict}
    try
        YAML.load(x; dicttype = dict_type, kw...)
    catch e
        throw(Serde.YAML.YamlSyntaxError("invalid YAML syntax", e))
    end
end

function Serde.YAML.parse_yaml(x::Vector{UInt8}; kw...)
    return parse_yaml(unsafe_string(pointer(x), length(x)); kw...)
end

end
