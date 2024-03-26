module DeYaml

using ..ParYaml
import Serde.to_deser
import Serde

function Serde.YAML.deser_yaml(::Type{T}, x; kw...) where {T}
    return to_deser(T, Serde.YAML.parse_yaml(x; kw...))
end

Serde.YAML.deser_yaml(::Type{Nothing}, _) = nothing
Serde.YAML.deser_yaml(::Type{Missing}, _) = missing

function Serde.YAML.deser_yaml(f::Function, x; kw...)
    object = Serde.YAML.parse_yaml(x; kw...)
    return to_deser(f(object), object)
end

end
