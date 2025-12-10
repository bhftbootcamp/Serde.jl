module Serde


function deser end
function parse_value end

abstract type DeserError <: Exception end

struct ParamError <: DeserError
    key::Any
end

function Base.show(io::IO, e::ParamError)
    return print(
        io,
        "ParamError: parameter '$(e.key)' was not passed or has the value 'nothing'",
    )
end

struct WrongType <: DeserError
    maintype::DataType
    key::Any
    value::Any
    from_type::Any
    to_type::Any
end

function Base.show(io::IO, e::WrongType)
    return print(
        io,
        "WrongType: for '$(e.maintype)' value '$(e.value)' has wrong type '$(e.key)::$(e.from_type)', must be '$(e.key)::$(e.to_type)'",
    )
end

struct DeserSyntaxError <: DeserError
    format::String
    message::String
    exception::Any
end

function Base.show(io::IO, e::DeserSyntaxError)
    return print(io, "DeserSyntaxError ($(e.format)): $(e.message), caused by: $(e.exception)")
end

export AbstractParsingStrategy
abstract type AbstractParsingStrategy end

# Ser
export to_json,
    to_pretty_json,
    to_messagepack

# De
export deser_json,
    deser_messagepack,
    DeserPipeline,
    deser_pipeline,
    @deser_pipeline

# Par
export parse_json,
    parse_messagepack,
    ParserPipeline,
    parser_pipeline,
    @parser_pipeline

# Ser
export to_json,
    to_pretty_json,
    to_messagepack,
    SerializerPipeline,
    serializer_pipeline,
    @serializer_pipeline

# Strategies
export JsonParsingStrategy,
    MessagePackParsingStrategy,
    JsonSerializer,
    MessagePackSerializer,
    default_json_strategy,
    default_messagepack_strategy

(ser_name(::Type{T}, ::Val{x})::Symbol) where {T,x} = x
(ser_value(::Type{T}, ::Val{x}, v::V)::V) where {T,x,V} = v
(ser_type(::Type{T}, v::V)::V) where {T,V} = v

(ser_ignore_field(::Type{T}, ::Val{x})::Bool) where {T,x} = false
(ser_ignore_field(::Type{T}, k::Val{x}, v::V)::Bool) where {T,x,V} = ser_ignore_field(T, k)
(ser_ignore_null(::Type{T})::Bool) where {T} = false

to_deser(::Type{T}, x) where {T} = deser(T, x)
to_deser(::Type{Nothing}, x) = nothing
to_deser(::Type{Missing}, x) = missing

include("MessagePack/MessagePack.jl")
include("Strategy/Strategy.jl")

include("Par/Par.jl")
include("Ser/Ser.jl")
include("De/De.jl")

include("Json/Par/Par.jl")
include("Json/Ser/Ser.jl")
include("Json/De/De.jl")
include("MessagePack/Par/Par.jl")
include("MessagePack/Ser/Ser.jl")
include("MessagePack/De/De.jl")

using .Par: ParserPipeline, parser_pipeline, @parser_pipeline
using .Ser: SerializerPipeline, serializer_pipeline, @serializer_pipeline
using .JsonPar: parse_json, JsonParsingStrategy, default_json_strategy
using .JsonSer: JsonSerializer
using .JsonDe: deser_json
using .MessagePackPar: parse_messagepack, MessagePackParsingStrategy, default_messagepack_strategy
using .MessagePackSer: MessagePackSerializer
using .MessagePackDe: deser_messagepack

import .JsonSer: to_json, to_pretty_json
import .MessagePackSer: to_messagepack
Base.include(Strategy, "Strategy/Custom.jl")

end
