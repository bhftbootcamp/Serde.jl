# Ser/Ser

(ser_name(::Type{T}, ::Val{x})::Symbol) where {T,x} = x
(ser_value(::Type{T}, ::Val{x}, v::V)::V) where {T,x,V} = v
(ser_type(::Type{T}, v::V)::V) where {T,V} = v

(ser_ignore_field(::Type{T}, ::Val{x})::Bool) where {T,x} = false
(ser_ignore_field(::Type{T}, k::Val{x}, v::V)::Bool) where {T,x,V} = ser_ignore_field(T, k)

include("SerCsv.jl")
using .SerCsv

include("SerJson.jl")
using .SerJson

include("SerQuery.jl")
using .SerQuery

include("SerToml.jl")
using .SerToml

include("SerXml.jl")
using .SerXml

include("SerYaml.jl")
using .SerYaml

include("SerBinaryJson.jl")
using .SerBinaryJson

include("SerMessagePack.jl")
using .SerMessagePack

include("SerBinaryStream.jl")
using .SerBinaryStream

serialize(s::Strategy.AbstractSerializerStrategy, data; kw...) = Strategy.serialize(s, data; kw...)
serialize(s::Strategy.AbstractSerializerStrategy, f::Function, data; kw...) = Strategy.serialize(s, f, data; kw...)
serialize(s::Strategy.AbstractSerializerStrategy, ::Type{T}, data; kw...) where {T} =
    Strategy.serialize(s, T, data; kw...)
