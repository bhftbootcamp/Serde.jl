module DeJson

using ..ParJson
import Serde.to_deser
import Serde

function Serde.JSON.deser_json(::Type{T}, x; kw...) where {T}
    return to_deser(T, Serde.JSON.parse_json(x; kw...))
end

Serde.JSON.deser_json(::Type{Nothing}, _) = nothing
Serde.JSON.deser_json(::Type{Missing}, _) = missing

function Serde.JSON.deser_json(f::Function, x; kw...)
    object = Serde.JSON.parse_json(x; kw...)
    return to_deser(f(object), object)
end

end
