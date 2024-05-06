module DeYaml

using ..ParYaml
import Serde.to_deser
import Serde

function Serde.from_string(ext::Val{:YAML}, ::Type{T}, x; kw...) where {T}
    return to_deser(T, Serde.from_string(ext, x; kw...))
end

Serde.from_string(::Val{:YAML}, ::Type{Nothing}, _) = nothing
Serde.from_string(::Val{:YAML}, ::Type{Missing}, _) = missing

function Serde.from_string(ext::Val{:YAML}, f::Function, x; kw...)
    object = Serde.parse(ext, x; kw...)
    return to_deser(f(object), object)
end

end
