module SerdeXml

using Dates
using UUIDs
using EzXML

export parse_xml, from_xml, try_from_xml, to_xml

import ..ParseError, ..SerdeError, ..to_deser, ..DefaultStrategy
import ..ser_name, ..ser_value, ..ser_type, ..ser_skip
import ..isnull, ..issimple

const XML_CONTENT_KEY = "_"

function _xml_escape_text(s::AbstractString)
    (occursin('&', s) || occursin('<', s) || occursin('>', s)) || return s
    io = IOBuffer()
    for c in s
        if c == '&'
            write(io, "&amp;")
        elseif c == '<'
            write(io, "&lt;")
        elseif c == '>'
            write(io, "&gt;")
        else
            write(io, c)
        end
    end
    return String(take!(io))
end

function _xml_escape_attr(s::AbstractString)
    (occursin('&', s) || occursin('<', s) || occursin('"', s) ||
     occursin('\n', s) || occursin('\r', s) || occursin('\t', s)) || return s
    io = IOBuffer()
    for c in s
        if c == '&'
            write(io, "&amp;")
        elseif c == '<'
            write(io, "&lt;")
        elseif c == '"'
            write(io, "&quot;")
        elseif c == '\n'
            write(io, "&#10;")
        elseif c == '\r'
            write(io, "&#13;")
        elseif c == '\t'
            write(io, "&#9;")
        else
            write(io, c)
        end
    end
    return String(take!(io))
end

function _xml_valid_name(s::AbstractString)
    isempty(s) && return false
    first_ok = false
    for (i, c) in enumerate(s)
        if i == 1
            first_ok = isletter(c) || c == '_' || c == ':'
            first_ok || return false
        else
            (isletter(c) || isdigit(c) || c == '_' || c == ':' || c == '-' || c == '.') || return false
        end
    end
    return first_ok
end

function _xml_has_text_content(node::EzXML.Node)
    is_content = istext(node) || iscdata(node) || !haselement(node)
    is_empty = isempty(nodecontent(node)) || all(isspace, nodecontent(node))
    return is_content && !is_empty
end

function _xml_parse_node(xml::AbstractString; kw...)
    doc = EzXML.parsexml(xml)
    return _xml_parse_node(root(doc); kw...)
end

function _xml_parse_node(node::EzXML.Node; dict_type::Type{D}, force_array::Bool) where {D<:AbstractDict}
    xml_dict = D()
    if _xml_has_text_content(node)
        xml_dict[XML_CONTENT_KEY] = nodecontent(node)
    end
    for attr in attributes(node)
        xml_dict[nodename(attr)] = nodecontent(attr)
    end
    for child in elements(node)
        child_name = nodename(child)
        child_dict = _xml_parse_node(child; dict_type, force_array)
        if !force_array && length(child_dict) == 1 && haskey(child_dict, XML_CONTENT_KEY)
            child_dict = child_dict[XML_CONTENT_KEY]
        end
        if haskey(xml_dict, child_name)
            if force_array || isa(xml_dict[child_name], AbstractVector)
                push!(xml_dict[child_name], child_dict)
            else
                xml_dict[child_name] = [xml_dict[child_name], child_dict]
            end
        else
            xml_dict[child_name] = force_array ? [child_dict] : child_dict
        end
    end
    return xml_dict
end

"""
    parse_xml(x::Union{AbstractString, Vector{UInt8}}; dict_type = Dict{String,Any}, force_array = false, kw...) -> Dict

Parse an XML string or byte vector into a nested `Dict` without mapping to a target type.

XML attributes and child elements are both represented as dict entries. Text content of
a node is stored under the special key `"_"`. When the same child element name appears
multiple times, the values are collected into a `Vector`.

# Arguments
- `x`: XML text as a `String` or `Vector{UInt8}`.

# Keyword arguments
- `dict_type::Type{<:AbstractDict}`: concrete dict type for nodes (default `Dict{String,Any}`).
- `force_array::Bool = false`: when `true`, all child elements are wrapped in `Vector`
  even if they appear only once.

# Returns
A nested dict representing the root XML element.

# Throws
- [`ParseError`](@ref): if `x` is malformed XML.

# Examples
```julia
julia> parse_xml("<root><x>1</x><y>2</y></root>")
Dict{String, Any}("x" => Dict{String, Any}("_" => "1"), "y" => Dict{String, Any}("_" => "2"))
```

See also: [`from_xml`](@ref).
"""
function parse_xml end

function parse_xml(
    x::AbstractString;
    dict_type::Type{D} = Dict{String,Any},
    force_array::Bool = false,
    kw...,
) where {D<:AbstractDict}
    try
        _xml_parse_node(x; dict_type, force_array, kw...)
    catch e
        throw(ParseError("XML", "invalid XML syntax", e))
    end
end

function parse_xml(x::Vector{UInt8}; kw...)
    return parse_xml(unsafe_string(pointer(x), length(x)); kw...)
end

"""
    from_xml(::Type{T}, x; kw...) -> T
    from_xml(strategy, ::Type{T}, x; kw...) -> T
    from_xml(f::Function, x; kw...) -> Any

Parse an XML string and deserialize the root element into type `T`.

The XML is first parsed into a nested dict via [`parse_xml`](@ref), then deserialized
using [`Serde.deser`](@ref). XML attributes and child elements are accessible as dict
keys. Text content of the root element is available under the key `"_"`.

Pass a context object `strategy` (e.g. [`CamelCase()`](@ref)) to apply global field-renaming.

# Arguments
- `::Type{T}`: target type to construct.
- `x`: XML text as a `String` or `Vector{UInt8}`.
- `strategy`: optional context object.

# Returns
A value of type `T`.

# Throws
- [`ParseError`](@ref): if `x` is malformed XML.
- [`MissingFieldError`](@ref): if a required struct field is absent.
- [`TypeMismatchError`](@ref): if a value cannot be coerced to the field type.

# Examples
```julia
julia> struct Point; x::Int; y::Int; end

julia> from_xml(Point, "<root x=\"1\" y=\"2\"/>")
Point(1, 2)
```

See also: [`to_xml`](@ref), [`parse_xml`](@ref).
"""
function from_xml(strategy, ::Type{T}, x; kw...) where {T}
    return to_deser(strategy, T, parse_xml(x; kw...))
end

from_xml(::Type{T}, x; kw...) where {T} = from_xml(DefaultStrategy(), T, x; kw...)
from_xml(::Type{Nothing}, _) = nothing
from_xml(::Type{Missing}, _) = missing

function from_xml(f::Function, x; kw...)
    object = parse_xml(x; kw...)
    return to_deser(f(object), object)
end

function _try_wrap(f, args...; kw...)
    try
        return f(args...; kw...)
    catch e
        return e isa SerdeError ? e : ParseError("XML", string(e), e)
    end
end

"""
    try_from_xml(::Type{T}, x; kw...) -> Union{T, SerdeError}
    try_from_xml(strategy, ::Type{T}, x; kw...) -> Union{T, SerdeError}

Like [`from_xml`](@ref) but returns a [`SerdeError`](@ref) instead of throwing on failure.

# Returns
- `T` on success.
- A [`ParseError`](@ref) or [`DeserError`](@ref) subtype on failure.

See also: [`from_xml`](@ref), [`SerdeError`](@ref).
"""
try_from_xml(::Type{T}, x; kw...)           where {T} = _try_wrap(from_xml, T, x; kw...)
try_from_xml(strategy, ::Type{T}, x; kw...) where {T} = _try_wrap(from_xml, strategy, T, x; kw...)

_xml_value(val::AbstractString; _...) = string(val)
_xml_value(val::Number; _...) = string(isnan(val) ? "nan" : val)
_xml_value(val::Symbol; kw...) = _xml_value(string(val); kw...)
_xml_value(val::AbstractChar; kw...) = _xml_value(string(val); kw...)
_xml_value(val::Bool; _...) = val ? "true" : "false"
_xml_value(val::Enum; kw...) = _xml_value(string(val); kw...)
_xml_value(val::Type; kw...) = _xml_value(string(val); kw...)
_xml_value(val::Dates.TimeType; kw...) = _xml_value(string(val); kw...)
_xml_value(val::Dates.DateTime; _...) = Dates.format(val, Dates.dateformat"YYYY-mm-dd\THH:MM:SS.sss")
_xml_value(val::Dates.Time; _...) = Dates.format(val, Dates.dateformat"HH:MM:SS.sss")
_xml_value(val::Dates.Date; _...) = Dates.format(val, Dates.dateformat"YYYY-mm-dd")
_xml_value(val::UUID; kw...) = _xml_value(string(val); kw...)

_xml_key(val::AbstractString; _...) = val
_xml_key(val::Integer; _...) = string(val)
_xml_key(val::Bool; _...) = val ? "true" : "false"
_xml_key(val::AbstractChar; kw...) = _xml_key(string(val); kw...)
_xml_key(val::Symbol; kw...) = _xml_key(string(val); kw...)

function _xml_attributes(node::AbstractDict)
    return filter(pair -> issimple(pair[2]) && pair[1] != XML_CONTENT_KEY, node)
end

function _xml_child_nodes(node::AbstractDict)
    child = empty(node)
    for pair in node
        if pair.first != XML_CONTENT_KEY && !issimple(pair.second)
            child[pair.first] = pair.second
        end
    end
    return child
end

function _xml_node_content(node::AbstractDict)
    if haskey(node, XML_CONTENT_KEY)
        v = node[XML_CONTENT_KEY]
        issimple(v) && return string(v)
    end
    return ""
end

function _xml_node_content(node::T) where {T}
    if hasfield(T, Symbol(XML_CONTENT_KEY))
        v = getfield(node, Symbol(XML_CONTENT_KEY))
        issimple(v) && return string(v)
    end
    return ""
end

function _xml_pairs(val::AbstractDict; kw...)
    return [(k, v) for (k, v) in val]
end

function _xml_pairs(val::AbstractVector{<:Tuple}; kw...)
    return val
end

@inline function _xml_shift!(io::IO, level::Int)
    for _ in 1:level
        print(io, "  ")
    end
end

function _xml_write_simple!(io::IO, key, val; level::Int)
    k = _xml_key(key)
    _xml_valid_name(k) || throw(ArgumentError("invalid XML element name: $(repr(k))"))
    _xml_shift!(io, level)
    print(io, '<', k, '>', _xml_escape_text(_xml_value(val)), "</", k, ">\n")
end

"""
    to_xml(val; key::String = "xml") -> String
    to_xml(strategy, val; key::String = "xml") -> String

Serialize `val` into an XML string.

The value is wrapped in a root element named by `key`. Scalar (primitive) struct fields
are serialized as XML attributes of the wrapping element. Nested structs produce nested
child elements. `nothing` and `missing` fields are omitted. `Vector` fields produce
repeated sibling elements with the same tag name.

Pass a context object `strategy` (e.g. [`CamelCase()`](@ref)) to apply global field-renaming.

All serialization traits ([`Serde.ser_name`](@ref), [`Serde.ser_value`](@ref),
[`Serde.ser_skip`](@ref)) are applied.

# Arguments
- `val`: the value to serialize.
- `strategy`: optional context object.

# Keyword arguments
- `key::String = "xml"`: name of the root XML element.

# Returns
An XML-formatted `String`.

# Examples
```julia
julia> struct Point; x::Int; y::Int; end

julia> to_xml(Point(1, 2)) |> print
<xml x="1" y="2"/>

julia> to_xml(Point(1, 2); key="point") |> print
<point x="1" y="2"/>
```

See also: [`from_xml`](@ref).
"""
function to_xml(strategy, val; key::String = "xml", kw...)::String
    io = IOBuffer()
    try
        _to_xml_inner!(io, strategy, Dict{String,Any}(key => val))
        return String(take!(io))
    finally
        close(io)
    end
end

to_xml(val; kw...) = to_xml(DefaultStrategy(), val; kw...)

function to_xml(io::IO, val; key::String = "xml", kw...)
    _to_xml_inner!(io, DefaultStrategy(), Dict{String,Any}(key => val))
    return nothing
end

function to_xml(io::IO, strategy, val; key::String = "xml", kw...)
    _to_xml_inner!(io, strategy, Dict{String,Any}(key => val))
    return nothing
end

# ── Context-aware serialization ──

function _xml_pairs(strategy, val::T; kw...) where {T}
    kv = Tuple[]
    N = fieldcount(T)
    Base.@nexprs 32 i -> begin
        if i <= N
            _fn_i = fieldnames(T)[i]
            _k_i = String(ser_name(strategy, T, Val(_fn_i)))
            _v_i = ser_type(strategy, T, ser_value(strategy, T, Val(_fn_i), getfield(val, _fn_i)))
            if !(_k_i == XML_CONTENT_KEY || isnull(_v_i) || ser_skip(strategy, T, Val(_fn_i), _v_i))
                push!(kv, (_k_i, _v_i))
            end
        end
    end
    if N > 32
        for field in fieldnames(T)[33:end]
            k = String(ser_name(strategy, T, Val(field)))
            v = ser_type(strategy, T, ser_value(strategy, T, Val(field), getfield(val, field)))
            (k == XML_CONTENT_KEY || isnull(v) || ser_skip(strategy, T, Val(field), v)) && continue
            push!(kv, (k, v))
        end
    end
    return kv
end

_xml_pairs(strategy, val::AbstractDict; kw...) = _xml_pairs(val; kw...)
_xml_pairs(strategy, val::AbstractVector{<:Tuple}; kw...) = val

function _xml_child_nodes(strategy, node::T; kw...) where {T}
    return filter(pair -> !issimple(pair[2]), _xml_pairs(strategy, node; kw...))
end

_xml_child_nodes(strategy, node::AbstractDict; kw...) = _xml_child_nodes(node)

function _xml_attributes(strategy, node::T) where {T}
    return filter(pair -> issimple(pair[2]) && pair[1] != XML_CONTENT_KEY, _xml_pairs(strategy, node))
end

_xml_attributes(strategy, node::AbstractDict) = _xml_attributes(node)

function _xml_attributes_string(strategy, node)
    io = IOBuffer()
    for (n, v) in _xml_attributes(strategy, node)
        nstr = _xml_key(n)
        _xml_valid_name(nstr) || throw(ArgumentError("invalid XML attribute name: $(repr(nstr))"))
        write(io, ' ')
        write(io, nstr)
        write(io, "=\"")
        write(io, _xml_escape_attr(_xml_value(v)))
        write(io, '"')
    end
    return String(take!(io))
end

_xml_pair!(io::IO, strategy, key, val::AbstractString; level::Int, kw...) = _xml_write_simple!(io, key, val; level)
_xml_pair!(io::IO, strategy, key, val::Symbol; level::Int, kw...) = _xml_write_simple!(io, key, val; level)
_xml_pair!(io::IO, strategy, key, val::Number; level::Int, kw...) = _xml_write_simple!(io, key, val; level)

function _xml_pair!(io::IO, strategy, key, val::AbstractVector; level::Int, kw...)
    for el in val
        if issimple(el)
            _xml_write_simple!(io, key, el; level)
        else
            _xml_pair!(io, strategy, key, el; level, kw...)
        end
    end
end

function _xml_write_node!(io::IO, strategy, key, node; level::Int, kw...)
    child = _xml_child_nodes(strategy, node)
    text = _xml_node_content(node)
    attrs = _xml_attributes_string(strategy, node)
    k = _xml_key(key)
    _xml_valid_name(k) || throw(ArgumentError("invalid XML element name: $(repr(k))"))
    if isempty(child) && isempty(text)
        _xml_shift!(io, level)
        print(io, '<', k, attrs, "/>\n")
    elseif isempty(text)
        _xml_shift!(io, level)
        print(io, '<', k, attrs, ">\n")
        _to_xml_inner!(io, strategy, child; level = level + 1)
        _xml_shift!(io, level)
        print(io, "</", k, ">\n")
    else
        _xml_shift!(io, level)
        print(io, '<', k, attrs, '>', _xml_escape_text(text))
        _to_xml_inner!(io, strategy, child; level = level + 1)
        print(io, "</", k, ">\n")
    end
end

function _xml_pair!(io::IO, strategy, key, val::AbstractDict; level::Int, kw...)
    _xml_write_node!(io, strategy, key, val; level, kw...)
end

function _xml_pair!(io::IO, strategy, key, val::T; level::Int, kw...) where {T}
    _xml_write_node!(io, strategy, key, val; level, kw...)
end

function _to_xml_inner!(io::IO, strategy, val; level::Int = 0, kw...)
    for (k, v) in _xml_pairs(strategy, val; kw...)
        _xml_pair!(io, strategy, k, v; level, kw...)
    end
end

end
