module SerMessagePack

export to_messagepack

using Dates
using UUIDs
using ..MessagePack
using ..Serde
using ..Strategy

isnull(::Any)::Bool = false
isnull(v::Missing)::Bool = true
isnull(v::Nothing)::Bool = true
isnull(v::Float64)::Bool = isnan(v) || isinf(v)

(ser_name(::Type{T}, k::Val{x})::Symbol) where {T,x} = Serde.ser_name(T, k)
(ser_value(::Type{T}, k::Val{x}, v::V)) where {T,x,V} = Serde.ser_value(T, k, v)
(ser_type(::Type{T}, v::V)) where {T,V} = Serde.ser_type(T, v)

(ser_ignore_field(::Type{T}, k::Val{x})::Bool) where {T,x} = Serde.ser_ignore_field(T, k)
(ser_ignore_field(::Type{T}, k::Val{x}, v::V)::Bool) where {T,x,V} = ser_ignore_field(T, k)
(ser_ignore_null(::Type{T})::Bool) where {T} = false

function normalize_struct(f::Function, val::T) where {T}
    dict = Dict{String,Any}()
    next = iterate(f(T))
    while next !== nothing
        field, state = next
        k = ser_name(T, Val(field))
        v = ser_type(T, ser_value(T, Val(field), getfield(val, field)))
        if (ser_ignore_null(T) && isnull(v)) || ser_ignore_field(T, Val(field), v)
            next = iterate(f(T), state)
            continue
        end
        dict[string(k)] = normalize_value(f, v)
        next = iterate(f(T), state)
    end
    return dict
end

function normalize_struct(val::T) where {T}
    return normalize_struct(fieldnames, val)
end

function normalize_value(f::Function, val)
    if val isa AbstractDict
        return Dict{String,Any}((string(k), normalize_value(f, v)) for (k, v) in val)
    elseif val isa AbstractVector{UInt8}
        return collect(val)
    elseif val isa AbstractArray
        return [normalize_value(f, v) for v in val]
    elseif val isa NamedTuple
        return Dict{String,Any}((string(k), normalize_value(f, v)) for (k, v) in pairs(val))
    elseif val isa UUID
        return string(val)
    elseif val isa Dates.DateTime
        return val
    elseif val isa Dates.TimeType
        return string(val)
    elseif val isa Regex
        return val
    elseif val isa Symbol
        return String(val)
    elseif val isa Missing
        return nothing
    elseif val === nothing
        return nothing
    elseif Base.isstructtype(typeof(val)) && !(val isa Number) && !(val isa AbstractString) && !(val isa Bool)
        return normalize_struct(f, val)
    else
        return val
    end
end

normalize_value(val) = normalize_value(fieldnames, val)

function to_messagepack(data; kw...)::Vector{UInt8}
    serializer = MessagePack.MsgPackSerializer()
    MessagePack.serialize(serializer, normalize_value(data))
    return take!(serializer.io)
end

function to_messagepack(f::Function, data; kw...)::Vector{UInt8}
    serializer = MessagePack.MsgPackSerializer()
    MessagePack.serialize(serializer, normalize_value(f, data))
    return take!(serializer.io)
end

end
