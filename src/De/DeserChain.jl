using .Strategy

export DeserPipeline, deser_pipeline, @deser_pipeline

const DeserStep = Union{Function, Strategy.AbstractParserStrategy}

struct DeserPipeline{T<:Tuple,M}
    steps::T
    mapper::M
end

DeserPipeline(steps::DeserStep...; mapper = _default_mapper) = deser_pipeline(steps...; mapper = mapper)

deser_pipeline(steps::DeserStep...; mapper = _default_mapper) = DeserPipeline(tuple(steps...), mapper)
deser_pipeline(pipe::DeserPipeline, steps::DeserStep...; mapper = pipe.mapper) =
    DeserPipeline((pipe.steps..., steps...), mapper)

function _call_mapper(f::Function, ::Type{T}, value, kw::NamedTuple) where {T}
    if isempty(kw)
        return f(T, value)
    end
    try
        return f(T, value; kw...)
    catch e
        if e isa MethodError
            return f(T, value)
        else
            rethrow()
        end
    end
end

function _call_deser(T::Type, value, kw::NamedTuple)
    if isempty(kw)
        return deser(T, value)
    end
    try
        return deser(T, value; kw...)
    catch e
        if e isa MethodError
            return deser(T, value)
        else
            rethrow()
        end
    end
end

_default_mapper(::Type{T}, value; kw...) where {T} = _call_deser(T, value, (; kw...))

function _deser_pipeline(pipe::DeserPipeline, ::Type{T}, input; kw...) where {T}
    kw_nt = (; kw...)
    result = input
    for step in pipe.steps
        if step isa Strategy.AbstractParserStrategy
            result = Strategy.parse(step, result; kw...)
        else
            result = Strategy._call_stage(step, result, kw_nt)
        end
    end
    return _call_mapper(pipe.mapper, T, result, kw_nt)
end

deser(pipe::DeserPipeline, ::Type{T}, input; kw...) where {T} = _deser_pipeline(pipe, T, input; kw...)
deser(::Type{T}, pipe::DeserPipeline, input; kw...) where {T} = _deser_pipeline(pipe, T, input; kw...)

function _collect_steps(block)
    if block isa Expr && block.head == :block
        return [stmt for stmt in block.args if !(stmt isa LineNumberNode)]
    else
        return [block]
    end
end

macro deser_pipeline(block)
    steps = _collect_steps(block)
    return esc(:(deser_pipeline($(steps...))))
end
