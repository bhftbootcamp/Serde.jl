export SerializerPipeline, serializer_pipeline, @serializer_pipeline

using ..Strategy

const SerializeStep = Union{Function, Strategy.AbstractSerializerStrategy}

struct SerializerPipeline{T<:Tuple} <: Strategy.AbstractSerializerStrategy
    steps::T
end

SerializerPipeline(steps::SerializeStep...) = serializer_pipeline(steps...)

serializer_pipeline(steps::SerializeStep...) = SerializerPipeline(steps)
serializer_pipeline(pipe::SerializerPipeline, steps::SerializeStep...) = SerializerPipeline((pipe.steps..., steps...))

function _serializer_call_step(step::SerializeStep, value, kw::NamedTuple)
    if step isa Strategy.AbstractSerializerStrategy
        clean_kw = (; (k => v for (k, v) in pairs(kw) if k != :field_function && k != :type_hint)...)
        type_hint = get(kw, :type_hint, nothing)
        field_fn = get(kw, :field_function, nothing)
        if isempty(clean_kw) && type_hint === nothing && field_fn === nothing
            return Strategy.serialize(step, value)
        end
        try
            if type_hint !== nothing
                return Strategy.serialize(step, type_hint, value; clean_kw...)
            elseif field_fn !== nothing
                return Strategy.serialize(step, field_fn, value; clean_kw...)
            else
                return Strategy.serialize(step, value; clean_kw...)
            end
        catch e
            if e isa MethodError
                if type_hint !== nothing
                    return Strategy.serialize(step, type_hint, value)
                elseif field_fn !== nothing
                    return Strategy.serialize(step, field_fn, value)
                else
                    return Strategy.serialize(step, value)
                end
            else
                rethrow()
            end
        end
    else
        return Strategy._call_stage(step, value, kw)
    end
end

function _serialize_pipeline(pipe::SerializerPipeline, data; kw...)
    kw_nt = (; kw...)
    result = data
    for step in pipe.steps
        result = _serializer_call_step(step, result, kw_nt)
    end
    return result
end

Strategy.serialize(pipe::SerializerPipeline, data; kw...) = _serialize_pipeline(pipe, data; kw...)
Strategy.serialize(pipe::SerializerPipeline, f::Function, data; kw...) =
    _serialize_pipeline(pipe, data; field_function=f, kw...)
Strategy.serialize(pipe::SerializerPipeline, ::Type{T}, data; kw...) where {T} =
    _serialize_pipeline(pipe, data; type_hint=T, kw...)

function _collect_steps(block)
    if block isa Expr && block.head == :block
        return [stmt for stmt in block.args if !(stmt isa LineNumberNode)]
    else
        return [block]
    end
end

macro serializer_pipeline(block)
    steps = _collect_steps(block)
    return esc(:(serializer_pipeline($(steps...))))
end
