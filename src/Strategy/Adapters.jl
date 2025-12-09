using ..Serde
import ..Serde: parse_json, parse_messagepack, to_json, to_pretty_json, to_messagepack

struct JsonParser <: AbstractParserStrategy end
struct MessagePackParser <: AbstractParserStrategy end

parse(::JsonParser, x::AbstractString; kw...) = Serde.parse_json(x; kw...)
parse(::MessagePackParser, x::AbstractVector{<:Integer}; kw...) = Serde.parse_messagepack(x; kw...)
parse(::MessagePackParser, x::IO; kw...) = Serde.parse_messagepack(x; kw...)
parse(::MessagePackParser, x::Serde.MessagePack.MsgPackSerializer; kw...) = Serde.parse_messagepack(x; kw...)

parse_json(parser::AbstractParserStrategy, x; kw...) = parse(parser, x; kw...)
parse_messagepack(parser::AbstractParserStrategy, x; kw...) = parse(parser, x; kw...)

using ..Serde: JsonSerializer, MessagePackSerializer

Serde.to_json(s::JsonSerializer, data; kw...) = serialize(s, data; kw...)
Serde.to_json(s::JsonSerializer, f::Function, data; kw...) = serialize(s, f, data; kw...)
Serde.to_pretty_json(::JsonSerializer, data; kw...) = serialize(JsonSerializer(pretty = true), data; kw...)
Serde.to_messagepack(s::MessagePackSerializer, data; kw...) = serialize(s, data; kw...)
Serde.to_messagepack(s::MessagePackSerializer, f::Function, data; kw...) = serialize(s, f, data; kw...)
