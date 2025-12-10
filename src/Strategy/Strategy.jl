module Strategy

using ..Serde

export AbstractParserStrategy,
       AbstractSerializerStrategy,
       parse,
       serialize
export Custom
abstract type AbstractParserStrategy end


function parse(s::AbstractParserStrategy, x::Vector{UInt8}; kw...)
    return parse(s, unsafe_string(pointer(x), length(x)); kw...)
end

abstract type AbstractSerializerStrategy end

function serialize(::AbstractSerializerStrategy, data; kw...)
    throw(MethodError(serialize, (:AbstractSerializerStrategy, typeof(data))))
end

struct JsonParser <: AbstractParserStrategy end
struct MessagePackParser <: AbstractParserStrategy end

parse(::JsonParser, x::AbstractString; kw...) = Serde.parse_json(x; kw...)
parse(::MessagePackParser, x::AbstractVector{<:Integer}; kw...) = Serde.parse_messagepack(x; kw...)
parse(::MessagePackParser, x::IO; kw...) = Serde.parse_messagepack(x; kw...)
parse(::MessagePackParser, x::Serde.MessagePack.MsgPackSerializer; kw...) = Serde.parse_messagepack(x; kw...)

_as_stage_vector(fs) = fs === nothing ? Function[] : fs isa Function ? Function[fs] : Function[f for f in fs]

_strip_internal_keywords(kw::NamedTuple) = (; (k => v for (k, v) in pairs(kw) if k != :field_function && k != :type_hint)...)

function _call_stage(f::Function, value, kw::NamedTuple)
    if isempty(kw)
        return f(value)
    end
    try
        return f(value; kw...)
    catch e
        if e isa MethodError
            return f(value)
        else
            rethrow()
        end
    end
end

function _run_stage_block(stages::Vector{Function}, value, kw::NamedTuple)
    result = value
    for f in stages
        result = _call_stage(f, result, kw)
    end
    return result
end


_coerce_writer(writer::AbstractSerializerStrategy) = (data; kw...) -> begin
    kw_nt = (; kw...)
    type_hint = get(kw_nt, :type_hint, nothing)
    field_fn = get(kw_nt, :field_function, nothing)
    clean_kw = _strip_internal_keywords(kw_nt)
    if type_hint !== nothing
        return serialize(writer, type_hint, data; clean_kw...)
    elseif field_fn !== nothing
        return serialize(writer, field_fn, data; clean_kw...)
    else
        return serialize(writer, data; clean_kw...)
    end
end

_coerce_writer(writer::Function) = writer

_coerce_parser(decoder::AbstractParserStrategy) = (input; kw...) -> parse(decoder, input; kw...)
_coerce_parser(decoder::Function) = decoder


end
