module SerToml

export to_toml

using Dates
using UUIDs
using ..Serde

struct TomlSerializationError <: Exception
    message::String
end

function Base.show(io::IO, e::TomlSerializationError)
    return print(io, "TomlSerializationError: " * e.message)
end

function toml_value(val::AbstractString; _...)::String
    return string('"', escape_string(val), '"')
end

toml_value(val::Symbol; kw...)::String = toml_value(string(val); kw...)
toml_value(val::AbstractChar; kw...)::String = toml_value(string(val); kw...)
toml_value(val::Bool; _...)::String = val ? "true" : "false"
toml_value(val::Number; _...)::String = string(isnan(val) ? "nan" : val)
toml_value(val::Enum; kw...)::String = toml_value(string(val); kw...)
toml_value(val::Type; kw...)::String = toml_value(string(val); kw...)
toml_value(val::Dates.TimeType; kw...)::String = toml_value(string(val); kw...)
toml_value(val::Dates.DateTime; _...)::String = Dates.format(val, Dates.dateformat"YYYY-mm-dd\THH:MM:SS.sss\Z")
toml_value(val::Dates.Time; _...)::String = Dates.format(val, Dates.dateformat"HH:MM:SS.sss")
toml_value(val::Dates.Date; _...)::String = Dates.format(val, Dates.dateformat"YYYY-mm-dd")
toml_value(val::UUID; kw...)::String = toml_value(string(val); kw...)

function isnumber(c::Char)::Bool
    return (c >= '0') & (c <= '9')
end

function isalphabetic(c::Char)::Bool
    return 'a' <= c <= 'z' || 'A' <= c <= 'Z'
end

function issymbol(c::Char)::Bool
    return c == '-' || c == '_'
end

function istomlkeyvalid(val::AbstractString)::Bool
    return all(x -> isalphabetic(x) || isnumber(x) || issymbol(x), val)
end

function toml_key(val::AbstractString; _...)
    return istomlkeyvalid(val) ? val : string('"', escape_string(val), '"')
end

toml_key(val::Integer; _...)::String = string(val)
toml_key(val::Bool; _...)::String = val ? "true" : "false"
toml_key(val::AbstractChar; kw...)::String = toml_key(string(val); kw...)
toml_key(val::Symbol; kw...)::String = toml_key(string(val); kw...)

issimple(::Any)::Bool = false
issimple(::AbstractString)::Bool = true
issimple(::Symbol)::Bool = true
issimple(::AbstractChar)::Bool = true
issimple(::Number)::Bool = true
issimple(::Enum)::Bool = true
issimple(::Type)::Bool = true
issimple(::Dates.TimeType)::Bool = true
issimple(::UUID)::Bool = true

function issimple(vec::AbstractVector{T})::Bool where {T}
    if isempty(vec) || issimple(vec[1])
        return true
    else
        return false
    end
end

function indent(level::Int64)::String
    return "  "^(level > 0 ? level - 1 : 0)
end

function toml_pair(key, val::AbstractString; level::Int64 = 0, kw...)::String
    return indent(level) * toml_key(key; kw...) * " = " * toml_value(val; kw...) * "\n"
end

function toml_pair(key, val::Symbol; level::Int64 = 0, kw...)::String
    return indent(level) * toml_key(key; kw...) * " = " * toml_value(val; kw...) * "\n"
end

function toml_pair(key, val::Number; level::Int64 = 0, kw...)::String
    return indent(level) * toml_key(key; kw...) * " = " * toml_value(val; kw...) * "\n"
end

function toml_pair(key, val::Dates.TimeType; level::Int64 = 0, kw...)::String
    return indent(level) * toml_key(key; kw...) * " = " * toml_value(val; kw...) * "\n"
end

function toml_pair(key, val::UUID; level::Int64 = 0, kw...)::String
    return indent(level) * toml_key(key; kw...) * " = " * toml_value(val; kw...) * "\n"
end

function toml_pair(key, val::T; parent_key::String = "", level::Int64 = 0, kw...)::String where {T}
    key = isempty(parent_key) ? toml_key(key) : parent_key * "." * toml_key(key; kw...)
    return "\n" * indent(level + 1) * "[" * key * "]" * "\n" * to_toml(val; parent_key = key, level = level + 1)
end

function create_simple_vector(key, val::AbstractVector{T}; level::Int64 = 0, kw...) where {T}
    buf = String[indent(level)*toml_key(key; kw...)*" = ["]
    for v in val
        if issimple(v)
            push!(buf, toml_value(v; kw...))
            push!(buf, ",")
        else
            throw(TomlSerializationError("mix simple and complex types"))
        end
    end
    buf[end] = "]" * "\n"
    return join(buf)
end

function create_complex_vector(key, val::AbstractVector{T}; parent_key::String = "", level::Int64 = 0, kw...) where {T}
    buf = String[]
    key = isempty(parent_key) ? toml_key(key) : parent_key * "." * toml_key(key; kw...)
    for v in val
        if !issimple(v)
            push!(
                buf,
                "\n" * indent(level + 1) * "[[" * key * "]]" * "\n" *
                join([toml_pair(k1, v1; parent_key = key, level = level + 1, kw...) for (k1, v1) in toml_pairs(v; kw...)]),
            )
        else
            throw(TomlSerializationError("mix simple and complex types"))
        end
    end
    return join(buf)
end

function toml_pair(key, val::AbstractVector{T}; level::Int64 = 0, kw...)::String where {T}
    if isempty(val)
        return indent(level) * "$key = []"
    elseif issimple(val[1])
        return create_simple_vector(key, val; level = level, kw...)
    else
        return create_complex_vector(key, val; level = level, kw...)
    end
end

function toml_pairs(val::AbstractDict; kw...)
    return sort([(k, v) for (k, v) in val], by = x -> !issimple(x[2]))
end

isnull(::Any) = false
isnull(v::Missing)::Bool = true
isnull(v::Nothing)::Bool = true

(ser_name(::Type{T}, k::Val{x})::Symbol) where {T,x} = Serde.ser_name(T, k)
(ser_value(::Type{T}, k::Val{x}, v::V)) where {T,x,V} = Serde.ser_value(T, k, v)
(ser_type(::Type{T}, v::V)) where {T,V} = Serde.ser_type(T, v)

(ser_ignore_field(::Type{T}, k::Val{x})::Bool) where {T,x} = Serde.ser_ignore_field(T, k)
(ser_ignore_field(::Type{T}, k::Val{x}, v::V)::Bool) where {T,x,V} = ser_ignore_field(T, k)

function toml_pairs(val::T; kw...) where {T}
    kv = Tuple[]

    for field in fieldnames(T)
        k = ser_name(T, Val(field))
        v = ser_type(T, ser_value(T, Val(field), getfield(val, field)))
        if (isnull(v) || ser_ignore_field(T, Val(field), v))
            continue
        end
        push!(kv, (k, v))
    end

    return sort(kv, by = x -> !issimple(x[2]))
end

function to_toml(data::T; kw...)::String where {T}
    return join([toml_pair(k, v; kw...) for (k, v) in toml_pairs(data; kw...)])
end

end
