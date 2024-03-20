module SerXml

export to_xml

using Dates
using ..Serde

const CONTENT_WORD = "_"

function shift(level::Int64)::String
    return "  "^level
end

# support function

issimple(::Any)::Bool = false
issimple(::AbstractString)::Bool = true
issimple(::Symbol)::Bool = true
issimple(::AbstractChar)::Bool = true
issimple(::Number)::Bool = true
issimple(::Enum)::Bool = true
issimple(::Type)::Bool = true
issimple(::Dates.TimeType)::Bool = true

function attributes(node::AbstractDict)
    return filter(pair -> issimple(pair[2]) && pair[1] != CONTENT_WORD, node)
end

function nodes(node::AbstractDict)
    df = empty(node)
    for pair in node
        if pair.first != CONTENT_WORD && !issimple(pair.second)
            df[pair.first] = pair.second
        end
    end
    return df
end

function content(node::AbstractDict)::String
    if haskey(node, CONTENT_WORD)
        cont = getindex(node, CONTENT_WORD)
        if issimple(cont)
            return string(cont)
        end
    end
    return ""
end

function attribute_xml(node::T) where {T}
    return join([" $n=\"$v\"" for (n, v) in attributes(node)])
end

# value

xml_value(val::AbstractString; _...)::String = string(val)
xml_value(val::Number; _...)::String = string(isnan(val) ? "nan" : val)
xml_value(val::Symbol; kw...)::String = xml_value(string(val); kw...)
xml_value(val::AbstractChar; kw...)::String = xml_value(string(val); kw...)
xml_value(val::Bool; _...)::String = val ? "true" : "false"
xml_value(val::Enum; kw...)::String = xml_value(string(val); kw...)
xml_value(val::Type; kw...)::String = xml_value(string(val); kw...)
xml_value(val::Dates.TimeType; kw...)::String = xml_value(string(val); kw...)
xml_value(val::Dates.DateTime; _...)::String = Dates.format(val, Dates.dateformat"YYYY-mm-dd\THH:MM:SS.sss\Z")
xml_value(val::Dates.Time; _...)::String = Dates.format(val, Dates.dateformat"HH:MM:SS.sss")
xml_value(val::Dates.Date; _...)::String = Dates.format(val, Dates.dateformat"YYYY-mm-dd")

# key

xml_key(val::AbstractString; _...) = val
xml_key(val::Integer; _...)::String = string(val)
xml_key(val::Bool; _...)::String = val ? "true" : "false"
xml_key(val::AbstractChar; kw...)::String = xml_key(string(val); kw...)
xml_key(val::Symbol; kw...)::String = xml_key(string(val); kw...)

# pair

function xml_pair(key, val::AbstractString; level::Int64, kw...)::String
    return shift(level) *
            "<" * xml_key(key; kw...) * ">" *
                xml_value(val) *
            "</" * xml_key(key; kw...) * ">" * "\n"
end

function xml_pair(key, val::Symbol; level::Int64, kw...)::String
    return shift(level) *
            "<" * xml_key(key; kw...) * ">" *
                xml_value(val) *
            "</" * xml_key(key; kw...) * ">" * "\n"
end

function xml_pair(key, val::Number; level::Int64, kw...)::String
    return shift(level) *
            "<" * xml_key(key; kw...) * ">" *
                xml_value(val) *
            "</" * xml_key(key; kw...) * ">" * "\n"
end

function xml_pair(key, val::AbstractVector{T}; level::Int64, kw...)::String where {T}
    buf = String[]
    for el in val
        if issimple(el)
            push!(
                buf,
                shift(level) *
                "<" * xml_key(key; kw...) * ">" *
                    xml_value(el) *
                "</" * xml_key(key; kw...) * ">" * "\n",
            )
        else
            push!(buf, xml_pair(key, el; level = level, kw...))
        end
    end
    return join(buf)
end

function xml_pair(key, val::AbstractDict; level::Int64, kw...)::String
    tags, cont = nodes(val), content(val)
    return if isempty(tags) && isempty(cont)
        shift(level) * "<" * xml_key(key; kw...) * attribute_xml(val) * "/>" * "\n"
    elseif isempty(cont)
        shift(level) *
        "<" * xml_key(key; kw...) * attribute_xml(val) * ">" *
            "\n" * _to_xml(tags; level = level + 1) * shift(level) *
        "</" * xml_key(key; kw...) * ">" * "\n"
    else
        shift(level) *
        "<" * xml_key(key; kw...) * attribute_xml(val) * ">" *
            cont * _to_xml(tags; level = level + 1) *
        "</" * xml_key(key; kw...) * ">" * "\n"
    end
end

function xml_pairs(val::AbstractDict; kw...)
    return [(k, v) for (k, v) in val]
end

(isnull(::Any)::Bool) = false
(isnull(v::Missing)::Bool) = true
(isnull(v::Nothing)::Bool) = true

function xml_pair(key, val::T; level::Int64, kw...)::String where {T}
    tags, cont = nodes(val), content(val)
    return if isempty(tags) && isempty(cont)
        shift(level) * "<" * xml_key(key; kw...) * attribute_xml(val) * "/>" * "\n"
    elseif isempty(cont)
        shift(level) *
        "<" * xml_key(key; kw...) * attribute_xml(val) * ">" * "\n" *
            _to_xml(tags; level = level + 1) * shift(level) *
        "</" * xml_key(key; kw...) * ">" * "\n"
    else
        shift(level) *
        "<" * xml_key(key; kw...) * attribute_xml(val) * ">" *
            cont * _to_xml(tags; level = level + 1) *
        "</" * xml_key(key; kw...) * ">" * "\n"
    end
end

(ser_name(::Type{T}, k::Val{x})::Symbol) where {T,x} = Serde.ser_name(T, k)
(ser_value(::Type{T}, k::Val{x}, v::V)) where {T,x,V} = Serde.ser_value(T, k, v)
(ser_type(::Type{T}, v::V)) where {T,V} = Serde.ser_type(T, v)

(ser_ignore_field(::Type{T}, k::Val{x})::Bool) where {T,x} = Serde.ser_ignore_field(T, k)
(ser_ignore_field(::Type{T}, k::Val{x}, v::V)::Bool) where {T,x,V} = ser_ignore_field(T, k)
(ser_ignore_null(::Type{T})::Bool) where {T} = true

function xml_pairs(val::T; kw...) where {T}
    kv = Tuple[]
    for field in fieldnames(T)
        k = String(ser_name(T, Val(field)))
        v = ser_type(T, ser_value(T, Val(field), getfield(val, field)))
        if k == CONTENT_WORD || ser_ignore_null(T) && isnull(v) || ser_ignore_field(T, Val(field), v)
            continue
        end
        push!(kv, (k, v))
    end
    return kv
end

function nodes(node::T) where {T}
    result = Dict{String,Any}()
    for el in xml_pairs(node)
        if !issimple(el[2])
            result[el[1]] = el[2]
        end
    end
    return result
end

function attributes(node::T) where {T}
    return filter(pair -> issimple(pair[2]) && pair[1] != CONTENT_WORD, xml_pairs(node))
end

function content(node::T)::String where {T}
    if hasfield(T, Symbol(CONTENT_WORD))
        cont = getfield(node, Symbol(CONTENT_WORD))
        if issimple(cont)
            return string(cont)
        end
    end
    return ""
end

function _to_xml(val::T; level::Int64 = 0, kw...)::String where {T}
    return join([xml_pair(k, v; level, kw...) for (k, v) in xml_pairs(val; level, kw...)])
end

"""
    to_xml(val; key::String = "xml") -> String

Serializes any nested data `val` into an XML string that follows the next rules:

- Values of **primitive types** are used as an element of the current tag.
- Vector elements will be used as sub-tag elements.
- Dictionaries are processed using the following rules:
    - Key names must be a string or a symbol types.
    - A key with a **non-empty string** value will be interpreted as a new sub-tag.
    - A key with an **empty string** value will be interpreted as an element of the current tag.
- Custom types are handled as follows:
    - The field name containing the **primitive type** will be used as an attribute for the current tag.
    - A field name containing a **composite type** (dictionary or other custom type) will be used as the name for the next sub-tag.
    - A primitive type field with **a special name "_"** will be used as an element for the current tag.

Thus, this method can serialize all basic data types and can work with any nesting level of a combination of dictionaries and custom data types.
The `key` keyword specifies the name of the root tag.

## Examples
```julia-repl
julia> struct Image
           dpi::Int64
           _::String
       end

julia> struct Data
           info::Dict
           image::Image
       end

julia> data_info = Dict("id" => "451", "status" => "OK", "_" => "employee");

julia> to_xml(Data(data_info, Image(200, "profile.png"))) |> print
<xml>
  <image dpi="200">profile.png</image>
  <info status="OK" id="451">employee</info>
</xml>
```
"""
function to_xml(val::T; key::String = "xml", kw...)::String where {T}
    return _to_xml(Dict{String,Any}(key => val))
end

end
