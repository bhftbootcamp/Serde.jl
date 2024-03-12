module DeJson

export deser_json

using ..ParJson
import Serde.to_deser

function deser_json(::Type{T}, x; kw...) where {T}
    return to_deser(T, parse_json(x; kw...))
end

deser_json(::Type{Nothing}, _) = nothing
deser_json(::Type{Missing}, _) = missing

function deser_json(f::Function, x; kw...)
    object = parse_json(x; kw...)
    return to_deser(f(object), object)
end

end
