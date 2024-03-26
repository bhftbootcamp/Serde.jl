module ParToml

using TOML
import Serde

function Serde.TOML.parse_toml(x::S; kw...) where {S<:AbstractString}
    try
        TOML.parse(x; kw...)
    catch e
        throw(Serde.TOML.TomlSyntaxError("invalid TOML syntax", e))
    end
end

function Serde.TOML.parse_toml(x::Vector{UInt8}; kw...)
    return Serde.TOML.parse_toml(unsafe_string(pointer(x), length(x)); kw...)
end

end
