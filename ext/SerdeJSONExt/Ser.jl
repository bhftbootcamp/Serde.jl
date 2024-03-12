module SerJson

export to_json
export to_pretty_json

using Dates
using Serde
using UUIDs

const JSON_NULL = "null"
const INDENT = "  "

# escaped string

const NEEDESCAPE = Set{UInt8}(UInt8['"', '\\', '\b', '\f', '\n', '\r', '\t'])

function escape_char(b)
    b == UInt8('"')  && return UInt8('"')
    b == UInt8('\\') && return UInt8('\\')
    b == UInt8('\b') && return UInt8('b')
    b == UInt8('\f') && return UInt8('f')
    b == UInt8('\n') && return UInt8('n')
    b == UInt8('\r') && return UInt8('r')
    b == UInt8('\t') && return UInt8('t')
    return 0x00
end

function escaped(b)
    if b == UInt8('/')
        return UInt8[UInt8('/')]
    elseif b >= 0x80
        return UInt8[b]
    elseif b in NEEDESCAPE
        return UInt8[UInt8('\\'), escape_char(b)]
    elseif iscntrl(Char(b))
        return UInt8[UInt8('\\'), UInt8('u'), Base.string(b, base = 16, pad = 4)...]
    else
        return UInt8[b]
    end
end

const ESCAPECHARS = Vector{UInt8}[escaped(b) for b = 0x00:0xff]

const ESCAPELENS = Int64[length(x) for x in ESCAPECHARS]

function escape_length(str)
    x = 0
    l = ncodeunits(str)
    @simd for i = 1:l
        @inbounds len = ESCAPELENS[codeunit(str, i)+1]
        x += len
    end
    return x
end

indent(l::Int64)::String = l > -1 ? "\n" * (INDENT^l) : ""

function json_value!(buf::IOBuffer, f::Function, val::AbstractString; kw...)::Nothing
    if escape_length(val) == ncodeunits(val)
        return print(buf, '\"', val, '\"')
    else
        return print(buf, '\"', escape_string(val), '\"')
    end
end

function json_value!(buf::IOBuffer, f::Function, val::Symbol; kw...)::Nothing
    return json_value!(buf, f, string(val); kw...)
end

function json_value!(buf::IOBuffer, f::Function, val::TimeType; kw...)::Nothing
    return json_value!(buf, f, string(val); kw...)
end

function json_value!(buf::IOBuffer, f::Function, val::UUID; kw...)::Nothing
    return json_value!(buf, f, string(val); kw...)
end

function json_value!(buf::IOBuffer, f::Function, val::AbstractChar; kw...)::Nothing
    return print(buf, '\"', val, '\"')
end

function json_value!(buf::IOBuffer, f::Function, val::Bool; kw...)::Nothing
    return print(buf, val)
end

function json_value!(buf::IOBuffer, f::Function, val::Number; kw...)::Nothing
    return isnan(val) || isinf(val) ? print(buf, JSON_NULL) : print(buf, val)
end

function json_value!(buf::IOBuffer, f::Function, val::Enum; kw...)::Nothing
    return print(buf, '\"', val, '\"')
end

function json_value!(buf::IOBuffer, f::Function, val::Missing; kw...)::Nothing
    return print(buf, JSON_NULL)
end

function json_value!(buf::IOBuffer, f::Function, val::Nothing; kw...)::Nothing
    return print(buf, JSON_NULL)
end

function json_value!(buf::IOBuffer, f::Function, val::Type; kw...)::Nothing
    return print(buf, '\"', val, '\"')
end

function json_value!(buf::IOBuffer, f::Function, val::Pair; l::Int64, kw...)::Nothing
    print(buf, "{", indent(l))
    json_value!(buf, f, first(val); l = l + (l != -1), kw...)
    print(buf, ":")
    json_value!(buf, f, last(val); l = l + (l != -1), kw...)
    return print(buf, indent(l - 1), "}")
end

function json_value!(buf::IOBuffer, f::Function, val::AbstractDict; l::Int64, kw...)::Nothing
    next = iterate(val)
    print(buf, "{", indent(l))
    while next !== nothing
        (k, v), index = next
        json_value!(buf, f, k; l = l + (l != -1), kw...)
        print(buf, ":")
        json_value!(buf, f, v; l = l + (l != -1), kw...)
        next = iterate(val, index)
        next === nothing || print(buf, ",", indent(l))
    end
    return print(buf, indent(l - 1), "}")
end

function json_value!(buf::IOBuffer, f::Function, val::AbstractVector; l::Int64, kw...)::Nothing
    next = iterate(val)
    print(buf, "[", indent(l))
    while next !== nothing
        item, index = next
        json_value!(buf, f, item; l = l + (l != -1), kw...)
        next = iterate(val, index)
        next === nothing || print(buf, ",", indent(l))
    end
    return print(buf, indent(l - 1), "]")
end

function json_value!(buf::IOBuffer, f::Function, val::Tuple; l::Int64, kw...)::Nothing
    next = iterate(val)
    print(buf, "[", indent(l))
    while next !== nothing
        item, index = next
        json_value!(buf, f, item; l = l + (l != -1), kw...)
        next = iterate(val, index)
        next === nothing || print(buf, ",", indent(l))
    end
    return print(buf, indent(l - 1), "]")
end

function json_value!(buf::IOBuffer, f::Function, val::AbstractSet; l::Int64, kw...)::Nothing
    next = iterate(val)
    print(buf, "[", indent(l))
    while next !== nothing
        item, index = next
        json_value!(buf, f, item; l = l + (l != -1), kw...)
        next = iterate(val, index)
        next === nothing || print(buf, ",", indent(l))
    end
    return print(buf, indent(l - 1), "]")
end

(isnull(::Any)::Bool) = false
(isnull(v::Missing)::Bool) = true
(isnull(v::Nothing)::Bool) = true
(isnull(v::Float64)::Bool) = isnan(v) || isinf(v)

(ser_name(::Type{T}, k::Val{x})::Symbol) where {T,x} = Serde.ser_name(T, k)
(ser_value(::Type{T}, k::Val{x}, v::V)) where {T,x,V} = Serde.ser_value(T, k, v)
(ser_type(::Type{T}, v::V)) where {T,V} = Serde.ser_type(T, v)

(ser_ignore_field(::Type{T}, k::Val{x})::Bool) where {T,x} = Serde.ser_ignore_field(T, k)
(ser_ignore_field(::Type{T}, k::Val{x}, v::V)::Bool) where {T,x,V} = ser_ignore_field(T, k)
(ser_ignore_null(::Type{T})::Bool) where {T} = false

function json_value!(buf::IOBuffer, f::Function, val::T; l::Int64, kw...)::Nothing where {T}
    next = iterate(f(T))
    print(buf, "{", indent(l))
    ignore_count::Int64 = 0
    while next !== nothing
        field, index = next
        k = ser_name(T, Val(field))
        v = ser_type(T, ser_value(T, Val(field), getfield(val, field)))
        if ser_ignore_null(T) && isnull(v) || ser_ignore_field(T, Val(field), v)
            next = iterate(f(T), index)
            ignore_count += 1
            continue
        end
        (index - ignore_count) == 2 || print(buf, ",", indent(l))
        json_value!(buf, f, k; l = l + (l != -1), kw...)
        print(buf, ":")
        json_value!(buf, f, v; l = l + (l != -1), kw...)
        next = iterate(f(T), index)
    end
    return print(buf, indent(l - 1), "}")
end

function json_value!(buf::IOBuffer, val::T; l::Int64, kw...)::Nothing where {T}
    return json_value!(buf, fieldnames, val; l = l, kw...)
end

function to_json(x...; kw...)::String
    buf = IOBuffer()
    json_value!(buf, x...; l = -1, kw...)
    return String(take!(buf))
end

function to_pretty_json(x...; kw...)::String
    buf = IOBuffer()
    json_value!(buf, x...; l = 1, kw...)
    return String(take!(buf))
end

end
