module ParToml

using TOML
import Serde

function Serde.parse(::Val{:TOML}, x::S; kw...) where {S<:AbstractString}
    try
        TOML.parse(x; kw...)
    catch e
        throw(Serde.TOML.TomlSyntaxError("invalid TOML syntax", e))
    end
end

function Serde.parse(ext::Val{:TOML}, x::Vector{UInt8}; kw...)
    return Serde.parse(ext, unsafe_string(pointer(x), length(x)); kw...)
end

end
