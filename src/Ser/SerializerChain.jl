export SerializerChain

using ..Strategy: AbstractSerializerStrategy
using ..Strategy

_ser_as_stage_vector(fs) = fs === nothing ? Function[] : fs isa Function ? Function[fs] : Function[f for f in fs]
_ser_strip_internal_keywords(kw) = (; (k => v for (k, v) in pairs(kw) if k != :field_function && k != :type_hint)...)

_ser_coerce_writer(writer::AbstractSerializerStrategy) = (data; kw...) -> begin
    kw_nt = (; kw...)
    clean_kw = _ser_strip_internal_keywords(kw_nt)
    type_hint = get(kw_nt, :type_hint, nothing)
    field_fn = get(kw_nt, :field_function, nothing)
    if type_hint !== nothing
        return serialize(writer, type_hint, data; clean_kw...)
    elseif field_fn !== nothing
        return serialize(writer, field_fn, data; clean_kw...)
    else
        return serialize(writer, data; clean_kw...)
    end
end
_ser_coerce_writer(writer::Function) = writer

mutable struct SerializerChain <: AbstractSerializerStrategy
    preprocess::Vector{Function}
    normalize::Vector{Function}
    transform::Vector{Function}
    prewrite::Vector{Function}
    writer::Function
    postwrite::Vector{Function}
    finalize::Vector{Function}
end

function SerializerChain(writer::Union{Function, AbstractSerializerStrategy};
        preprocess = Function[],
        normalize = Function[],
        transform = Function[],
        prewrite = Function[],
        postwrite = Function[],
        finalize = Function[]
    )
    return SerializerChain(
        _ser_as_stage_vector(preprocess),
        _ser_as_stage_vector(normalize),
        _ser_as_stage_vector(transform),
        _ser_as_stage_vector(prewrite),
        _ser_coerce_writer(writer),
        _ser_as_stage_vector(postwrite),
        _ser_as_stage_vector(finalize),
    )
end

SerializerChain(; writer, kwargs...) = SerializerChain(writer; kwargs...)

function _ser_call_stage(f::Function, value, kw::NamedTuple)
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

function _ser_run_stage_block(stages::Vector{Function}, value, kw::NamedTuple)
    result = value
    for f in stages
        result = _ser_call_stage(f, result, kw)
    end
    return result
end

function _serialize_chain(chain::SerializerChain, data; kw...)
    kw_nt = (; kw...)
    payload = _ser_run_stage_block(chain.preprocess, data, kw_nt)
    payload = _ser_run_stage_block(chain.normalize, payload, kw_nt)
    payload = _ser_run_stage_block(chain.transform, payload, kw_nt)
    payload = _ser_run_stage_block(chain.prewrite, payload, kw_nt)
    written = _ser_call_stage(chain.writer, payload, kw_nt)
    written = _ser_run_stage_block(chain.postwrite, written, kw_nt)
    return _ser_run_stage_block(chain.finalize, written, kw_nt)
end

function _serializer_stage_vector(chain::SerializerChain, stage::Symbol)
    if stage === :preprocess
        return chain.preprocess
    elseif stage === :normalize
        return chain.normalize
    elseif stage === :transform
        return chain.transform
    elseif stage === :prewrite
        return chain.prewrite
    elseif stage === :postwrite
        return chain.postwrite
    elseif stage === :finalize
        return chain.finalize
    else
        throw(ArgumentError("Unknown serializer stage: $(stage)"))
    end
end

function Serde.append_stage!(chain::SerializerChain, stage::Symbol, f::Function)
    if stage === :writer
        chain.writer = _ser_coerce_writer(f)
    else
        push!(_serializer_stage_vector(chain, stage), f)
    end
    return chain
end

function Serde.replace_stage!(chain::SerializerChain, stage::Symbol, fs)
    if stage === :writer
        chain.writer = _ser_coerce_writer(fs isa AbstractSerializerStrategy ? fs : (fs isa Function ? fs : first(fs)))
    elseif stage in (:preprocess, :normalize, :transform, :prewrite, :postwrite, :finalize)
        setfield!(chain, stage, _ser_as_stage_vector(fs))
    else
        throw(ArgumentError("Unknown serializer stage: $(stage)"))
    end
    return chain
end

Strategy.serialize(chain::SerializerChain, data; kw...) = _serialize_chain(chain, data; kw...)
Strategy.serialize(chain::SerializerChain, f::Function, data; kw...) =
    _serialize_chain(chain, data; field_function=f, kw...)
Strategy.serialize(chain::SerializerChain, ::Type{T}, data; kw...) where {T} =
    _serialize_chain(chain, data; type_hint=T, kw...)
