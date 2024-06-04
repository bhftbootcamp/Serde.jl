module DeJson

using ..ParJson
import Serde.to_deser
import Serde

function Serde.from_string(ext::Val{:JSON}, ::Type{T}, x; kw...) where {T}
    return to_deser(T, Serde.parse(ext, x; kw...))
end

Serde.from_string(::Val{:JSON}, ::Type{Nothing}, _) = nothing
Serde.from_string(::Val{:JSON}, ::Type{Missing}, _) = missing

function Serde.from_string(ext::Val{:JSON}, f::Function, x; kw...)
    object = Serde.parse(ext, x; kw...)
    return to_deser(f(object), object)
end

end
