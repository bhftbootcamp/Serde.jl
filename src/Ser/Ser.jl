module Ser

using ..Serde
include("SerializerChain.jl")


serialize(s::Strategy.AbstractSerializerStrategy, data; kw...) = Strategy.serialize(s, data; kw...)
serialize(s::Strategy.AbstractSerializerStrategy, f::Function, data; kw...) = Strategy.serialize(s, f, data; kw...)
serialize(s::Strategy.AbstractSerializerStrategy, ::Type{T}, data; kw...) where {T} =
    Strategy.serialize(s, T, data; kw...)

end
