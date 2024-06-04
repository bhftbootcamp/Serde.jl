module DeQuery

using ..ParQuery
import ...Serde, ...Serde.to_deser

function Serde.from_string(ext::Val{:Serde_Query}, ::Type{T}, x; kw...) where {T}
    return to_deser(T, Serde.parse(ext, x; backbone=T, kw...))
end

Serde.from_string(::Val{:Serde_Query}, ::Type{Nothing}, _) = nothing
Serde.from_string(::Val{:Serde_Query}, ::Type{Missing}, _) = missing

function Serde.from_string(ext::Val{:Serde_Query}, f::Function, x; kw...)
    object = Serde.parse(ext, x; kw...)
    return to_deser(f(object), object)
end

end
