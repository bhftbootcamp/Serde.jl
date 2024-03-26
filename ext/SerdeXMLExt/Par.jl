module ParXml

using EzXML
import Serde

function _xml2dict(xml::AbstractString; kw...)
    doc = EzXML.parsexml(xml)
    return _xml2dict(root(doc); kw...)
end

function _has_content(node::EzXML.Node)::Bool
    is_content = istext(node) || iscdata(node) || !haselement(node)
    is_empty = isempty(nodecontent(node)) || all(isspace, nodecontent(node))
    return is_content && !is_empty
end

function _xml2dict(node::EzXML.Node; dict_type::Type{D}) where {D<:AbstractDict}
    xml_dict = D()

    if _has_content(node)
        xml_dict["_"] = nodecontent(node)
    end

    for attr in attributes(node)
        xml_dict[nodename(attr)] = nodecontent(attr)
    end

    for child in elements(node)
        child_name = nodename(child)
        child_dict = _xml2dict(child; dict_type = dict_type)

        if haskey(xml_dict, child_name)
            if isa(xml_dict[child_name], AbstractVector)
                push!(xml_dict[child_name], child_dict)
            else
                xml_dict[child_name] = [xml_dict[child_name], child_dict]
            end
        else
            xml_dict[child_name] = child_dict
        end
    end

    return xml_dict
end

function Serde.XML.parse_xml(x::S; dict_type::Type{D} = Dict{String,Any}, kw...) where {S<:AbstractString,D<:AbstractDict}
    try
        _xml2dict(x; dict_type = dict_type, kw...)
    catch e
        throw(Serde.XML.XmlSyntaxError("invalid XML syntax", e))
    end
end

function Serde.XML.parse_xml(x::Vector{UInt8}; kw...)
    return Serde.XML.parse_xml(unsafe_string(pointer(x), length(x)); kw...)
end

end
