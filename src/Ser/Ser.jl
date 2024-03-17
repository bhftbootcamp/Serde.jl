# Ser/Ser

(ser_name(::Type{T}, ::Val{x})::Symbol) where {T,x} = x
(ser_value(::Type{T}, ::Val{x}, v::V)::V) where {T,x,V} = v
(ser_type(::Type{T}, v::V)::V) where {T,V} = v

(ser_ignore_field(::Type{T}, ::Val{x})::Bool) where {T,x} = false
(ser_ignore_field(::Type{T}, k::Val{x}, v::V)::Bool) where {T,x,V} = ser_ignore_field(T, k)
(ser_ignore_null(::Type{T})::Bool) where {T} = true

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
