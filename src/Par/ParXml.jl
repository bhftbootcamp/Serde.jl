module ParXml

export XmlSyntaxError
export parse_xml

using EzXML

"""
    XmlSyntaxError <: Exception

Exception thrown when a [`parse_xml`](@ref) fails due to incorrect XML syntax or any underlying error that occurs during parsing.

## Fields
- `message::String`: The error message.
- `exception::Exception`: The catched exception.
"""
struct XmlSyntaxError <: Exception
    message::String
    exception::EzXML.XMLError
end

Base.show(io::IO, e::XmlSyntaxError) = print(io, e.message)

function is_empty(node::EzXML.Node)
    node_elem = nodecontent(node)
    return isempty(node_elem) || all(isspace, node_elem)
end

is_text(node::EzXML.Node) = istext(node) || iscdata(node)

has_text(node::EzXML.Node) = is_text(node) && !is_empty(node)

function has_mixed_tags(nodes::EzXML.Node)
    tags = []
    for node_elem in eachelement(nodes)
        tag = nodename(node_elem)
        if isempty(tags) || tag != tags[end]
            if tag in tags
                return true
            end
            push!(tags, tag)
        end
    end
    return false
end

function parse_doc(xml::EzXML.Document; decl_struct = false, kw...)
    res = Dict{String,Any}()
    res["version"] = version(xml)
    try
        res["encoding"] = encoding(xml)
    catch
    end
    root_name = nodename(root(xml))
    res[root_name] = parse_doc(root(xml); kw...)
    return (decl_struct ? res : res[root_name])
end

function read_element(node::EzXML.Node, res::Dict{String,Any})
    k = nodename(node)
    v = parse_doc(node)

    if haskey(res, "_")
        push!(res["_"], Dict{String,Any}(k => v))
    elseif haskey(res, k)
        arr = isa(res[k], Array) ? res[k] : Any[res[k]]
        push!(arr, v)
        res[k] = arr
    else
        res[k] = v
    end
end

function parse_doc(nodes::EzXML.Node; kw...)
    res = Dict{String,Any}()

    for attr in eachattribute(nodes)
        res[nodename(attr)] = nodecontent(attr)
    end

    if any(has_text, eachnode(nodes)) || has_mixed_tags(nodes)
        res["_"] = Any[]
    end

    for node in eachnode(nodes)
        if iselement(node)
            read_element(node, res)
        elseif is_text(node) && haskey(res, "_") && strip(nodecontent(node)) != ""
            push!(res["_"], strip(nodecontent(node)))
        end
    end

    if haskey(res, "_")
        v = res["_"]
        if length(v) == 1 && isa(v[1], AbstractString)
            res["_"] = v[1]
            if length(res) == 1
                res = res["_"]
            end
        end
    end

    return res
end

function parse_string(xml_string::AbstractString; kw...)
    return parse_doc(parsexml(xml_string); kw...)
end

"""
    parse_xml(x::AbstractString; kw...) -> Dict{String,Any}
    parse_xml(x::Vector{UInt8}; kw...) -> Dict{String,Any}

Parse a XML string `x` (or vector of UInt8) into a dictionary.

## Keyword arguments
- `decl_struct::Bool = false`: If false, only the contents of the root node are returned. If true, the declaration tags and the entire root node are returned.

## Examples

```julia-repl
julia> xml = \"\"\"
       <?xml version="1.0" encoding="UTF-8" ?>
       <root>
       <string>qwerty</string>
       <vector>1</vector>
       <vector>2</vector>
       <vector>3</vector>
       <dictionary>
           <string>123</string>
       </dictionary>
       </root>
       \"\"\";

julia> parse_xml(xml)
Dict{String, Any} with 3 entries:
  "string"     => "qwerty"
  "vector"     => Any["1", "2", "3"]
  "dictionary" => Dict{String, Any}("string"=>"123")
```
"""
function parse_xml end

function parse_xml(x::S; kw...) where {S<:AbstractString}
    try
        parse_string(x; kw...)
    catch e
        throw(XmlSyntaxError("Invalid XML syntax", e))
    end
end

function parse_xml(x::Vector{UInt8}; kw...)
    return parse_xml(unsafe_string(pointer(x), length(x)); kw...)
end

end
