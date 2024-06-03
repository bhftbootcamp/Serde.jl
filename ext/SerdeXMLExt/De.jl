module DeXml

using ..ParXml
import Serde.to_deser
import Serde

function Serde.from_string(ext::Val{:EzXML}, ::Type{T}, x; kw...) where {T}
    return to_deser(T, Serde.from_string(ext, x; kw...))
end

Serde.from_string(::Val{:EzXML}, ::Type{Nothing}, _) = nothing
Serde.from_string(::Val{:EzXML}, ::Type{Missing}, _) = missing

function Serde.from_string(ext::Val{:EzXML}, f::Function, x; kw...)
    object = Serde.parse(ext, x; kw...)
    return to_deser(f(object), object)
end

end
