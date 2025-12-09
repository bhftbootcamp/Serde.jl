using .Strategy

mutable struct DeserChain
    preprocess::Vector{Function}
    parse_stage::Union{Nothing,Function}
    normalize::Vector{Function}
    pre_map::Vector{Function}
    mapper::Function
    post_map::Vector{Function}
    finalize::Vector{Function}
end

_deser_stage_vector(fs) = fs === nothing ? Function[] : fs isa Function ? Function[fs] : Function[f for f in fs]

function _coerce_parse_stage(p)
    if p === nothing
        return nothing
    elseif p isa Strategy.AbstractParserStrategy
        return (input; kw...) -> Strategy.parse(p, input; kw...)
    elseif p isa Function
        return p
    else
        throw(ArgumentError("Unsupported parse stage type: $(typeof(p))"))
    end
end

function _call_stage_or_value(f::Function, value, kw::NamedTuple)
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
        result = _call_stage_or_value(f, result, kw)
    end
    return result
end

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

function DeserChain(; mapper = _default_mapper,
            preprocess = Function[],
            parse = nothing,
            normalize = Function[],
            pre_map = Function[],
            post_map = Function[],
            finalize = Function[])
    return DeserChain(
        _deser_stage_vector(preprocess),
        _coerce_parse_stage(parse),
        _deser_stage_vector(normalize),
        _deser_stage_vector(pre_map),
        mapper,
        _deser_stage_vector(post_map),
        _deser_stage_vector(finalize),
    )
end

function deser(chain::DeserChain, ::Type{T}, input; kw...) where {T}
    kw_nt = (; kw...)
    value = _run_stage_block(chain.preprocess, input, kw_nt)
    if chain.parse_stage !== nothing
        value = _call_stage_or_value(chain.parse_stage, value, kw_nt)
    end
    value = _run_stage_block(chain.normalize, value, kw_nt)
    value = _run_stage_block(chain.pre_map, value, kw_nt)
    mapped = _call_mapper(chain.mapper, T, value, kw_nt)
    mapped = _run_stage_block(chain.post_map, mapped, kw_nt)
    return _run_stage_block(chain.finalize, mapped, kw_nt)
end

deser(::Type{T}, chain::DeserChain, input; kw...) where {T} = deser(chain, T, input; kw...)

function _deser_stage_vector_ref(chain::DeserChain, stage::Symbol)
    if stage === :preprocess
        return chain.preprocess
    elseif stage === :normalize
        return chain.normalize
    elseif stage === :pre_map
        return chain.pre_map
    elseif stage === :post_map
        return chain.post_map
    elseif stage === :finalize
        return chain.finalize
    else
        throw(ArgumentError("Unknown deserialization stage: $(stage)"))
    end
end

function append_stage!(chain::DeserChain, stage::Symbol, f::Function)
    if stage === :mapper
        chain.mapper = f
    elseif stage === :parse
        chain.parse_stage = _coerce_parse_stage(f)
    else
        push!(_deser_stage_vector_ref(chain, stage), f)
    end
    return chain
end

function replace_stage!(chain::DeserChain, stage::Symbol, fs)
    if stage === :mapper
        chain.mapper = fs isa Function ? fs : first(_deser_stage_vector(fs))
    elseif stage === :parse
        chain.parse_stage = _coerce_parse_stage(fs)
    elseif stage in (:preprocess, :normalize, :pre_map, :post_map, :finalize)
        setfield!(chain, stage, _deser_stage_vector(fs))
    else
        throw(ArgumentError("Unknown deserialization stage: $(stage)"))
    end
    return chain
end
