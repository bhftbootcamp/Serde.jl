module DeToml

using ..ParToml
import Serde.to_deser
import Serde

function Serde.TOML.deser_toml(::Type{T}, x; kw...) where {T}
    return to_deser(T, Serde.TOML.parse_toml(x; kw...))
end

Serde.TOML.deser_toml(::Type{Nothing}, _) = nothing
Serde.TOML.deser_toml(::Type{Missing}, _) = missing

function Serde.TOML.deser_toml(f::Function, x; kw...)
    object = Serde.TOML.parse_toml(x; kw...)
    return to_deser(f(object), object)
end

end
