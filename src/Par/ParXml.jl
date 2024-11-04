module ParXml

export XmlSyntaxError
export parse_xml

using EzXML

"""
    XmlSyntaxError <: Exception

Exception thrown when a [`parse_xml`](@ref) fails due to incorrect XML syntax or any underlying error that occurs during parsing.

## Fields
- `message::String`: The error message.
- `exception::Exception`: The exception that was caught.
"""
struct XmlSyntaxError <: Exception
    message::String
    exception::Union{Exception,EzXML.XMLError}
end

function Base.show(io::IO, e::XmlSyntaxError)
    return print(io, e.message, ", caused by: ", e.exception)
end

function _xml2dict(xml::AbstractString; kw...)
    doc = EzXML.parsexml(xml)
    return _xml2dict(root(doc); kw...)
end

function _has_content(node::EzXML.Node)::Bool
    is_content = istext(node) || iscdata(node) || !haselement(node)
    is_empty = isempty(nodecontent(node)) || all(isspace, nodecontent(node))
    return is_content && !is_empty
end

function _xml2dict(node::EzXML.Node; dict_type::Type{D}, vectorize::Bool) where {D<:AbstractDict}
    xml_dict = D()

    if _has_content(node)
        xml_dict["_"] = nodecontent(node)
    end

    for attr in attributes(node)
        xml_dict[nodename(attr)] = nodecontent(attr)
    end

    for child in elements(node)
        child_name = nodename(child)
        child_dict = _xml2dict(child; dict_type, vectorize)

        if haskey(xml_dict, child_name)
            if isa(xml_dict[child_name], AbstractVector)
                push!(xml_dict[child_name], child_dict)
            else
                xml_dict[child_name] = [xml_dict[child_name], child_dict]
            end
        else
            xml_dict[child_name] = if vectorize
                isa(child_dict, AbstractVector) ? child_dict : [child_dict]
            else
                child_dict
            end 
        end
    end

    return xml_dict
end

"""
    parse_xml(x::AbstractString; kw...) -> Dict{String,Any}
    parse_xml(x::Vector{UInt8}; kw...) -> Dict{String,Any}

Parse an XML string `x` (or vector of UInt8) into a dictionary.

## Keyword arguments
- `dict_type::Type{<:AbstractDict} = Dict`: The type of the dictionary to be returned.

## Examples

```julia-repl
julia> xml = \"\"\"
           <book id="bk101">
              <title>Advanced Julia Programming</title>
              <authors>
                  <author lang="en">John Doe</author>
                  <author lang="es">Juan Pérez</author>
              </authors>
              <year>2024</year>
              <price>49.99</price>
           </book>
       \"\"\"

julia> parse_xml(xml)
Dict{String, Any} with 5 entries:
  "price"   => Dict{String, Any}("_"=>"49.99")
  "year"    => Dict{String, Any}("_"=>"2024")
  "id"      => "bk101"
  "title"   => Dict{String, Any}("_"=>"Advanced Julia Programming")
  "authors" => Dict{String, Any}("author"=>Dict{String, Any}[Dict("lang"=>"en", "_"=>"John Doe"), Dict("lang"=>"es", "_"=>"Juan Pérez")])
```
"""
function parse_xml end

function parse_xml(x::S; dict_type::Type{D} = Dict{String,Any}, vectorize::Bool = false, kw...) where {S<:AbstractString,D<:AbstractDict}
    try
        _xml2dict(x; dict_type, vectorize, kw...)
    catch e
        throw(XmlSyntaxError("invalid XML syntax", e))
    end
end

function parse_xml(x::Vector{UInt8}; kw...)
    return parse_xml(unsafe_string(pointer(x), length(x)); kw...)
end

end
