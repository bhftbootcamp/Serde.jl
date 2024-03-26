module SerXml

using Dates
using UUIDs
import Serde
import Serde.XML: isnull, ser_name, ser_type, ser_type, ser_ignore_field, ser_ignore_null,
    ser_value

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
issimple(::UUID)::Bool = true

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
xml_value(val::UUID; _...)::String = xml_value(string(val); kw...)

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

function Serde.XML.to_xml(val::T; key::String = "xml", kw...)::String where {T}
    return _to_xml(Dict{String,Any}(key => val))
end

end
