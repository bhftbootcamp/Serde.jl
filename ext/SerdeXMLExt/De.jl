module DeXml

using ..ParXml
import Serde.to_deser
import Serde

#function Serde.XML.deser_xml(::Type{T}, x; kw...) where {T}
#    return to_deser(T, Serde.XML.parse_xml(x; kw...))
#end
function Serde.from_string(ext::Val{:EzXML}, ::Type{T}, x; kw...) where {T}
    return to_deser(T, Serde.from_string(ext, x; kw...))
end

#Serde.XML.deser_xml(::Type{Nothing}, _) = nothing
Serde.from_string(::Val{:EzXML}, ::Type{Nothing}, _) = nothing
#Serde.XML.deser_xml(::Type{Missing}, _) = missing
Serde.from_string(::Val{:EzXML}, ::Type{Missing}, _) = missing

#function Serde.XML.deser_xml(f::Function, x; kw...)
#    object = Serde.XML.parse_xml(x; kw...)
#    return to_deser(f(object), object)
#end
function Serde.from_string(ext::Val{:EzXML}, f::Function, x; kw...)
    object = Serde.parse(ext, x; kw...)
    return to_deser(f(object), object)
end

end
