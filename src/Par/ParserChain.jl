export ParserChain

using ..Serde
using ..Strategy: AbstractParserStrategy
using ..Strategy

_par_as_stage_vector(fs) = fs === nothing ? Function[] : fs isa Function ? Function[fs] : Function[f for f in fs]

function _par_call_stage(f::Function, value, kw::NamedTuple)
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

function _par_run_stage_block(stages::Vector{Function}, value, kw::NamedTuple)
    result = value
    for f in stages
        result = _par_call_stage(f, result, kw)
    end
    return result
end

_par_coerce_parser(decoder::AbstractParserStrategy) = (input; kw...) -> parse(decoder, input; kw...)
_par_coerce_parser(decoder::Function) = decoder

mutable struct ParserChain <: AbstractParserStrategy
    preprocess::Vector{Function}
    decode::Function
    normalize::Vector{Function}
    pre_transform::Vector{Function}
    transform::Vector{Function}
    post_transform::Vector{Function}
    finalize::Vector{Function}
end

function ParserChain(decoder::Union{Function, AbstractParserStrategy};
        preprocess = Function[],
        normalize = Function[],
        pre_transform = Function[],
        transform = Function[],
        post_transform = Function[],
        finalize = Function[]
    )
    return ParserChain(
        _par_as_stage_vector(preprocess),
        _par_coerce_parser(decoder),
        _par_as_stage_vector(normalize),
        _par_as_stage_vector(pre_transform),
        _par_as_stage_vector(transform),
        _par_as_stage_vector(post_transform),
        _par_as_stage_vector(finalize),
    )
end

ParserChain(; decode, kwargs...) = ParserChain(decode; kwargs...)

function _parse_chain(chain::ParserChain, x; kw...)
    kw_nt = (; kw...)
    value = _par_run_stage_block(chain.preprocess, x, kw_nt)
    value = _par_call_stage(chain.decode, value, kw_nt)
    value = _par_run_stage_block(chain.normalize, value, kw_nt)
    value = _par_run_stage_block(chain.pre_transform, value, kw_nt)
    value = _par_run_stage_block(chain.transform, value, kw_nt)
    value = _par_run_stage_block(chain.post_transform, value, kw_nt)
    return _par_run_stage_block(chain.finalize, value, kw_nt)
end

parse(chain::ParserChain, x; kw...) = _parse_chain(chain, x; kw...)
parse(chain::ParserChain, x::AbstractString; kw...) = _parse_chain(chain, x; kw...)
parse(chain::ParserChain, x::Vector{UInt8}; kw...) = _parse_chain(chain, x; kw...)

Strategy.parse(chain::ParserChain, x; kw...) = _parse_chain(chain, x; kw...)
Strategy.parse(chain::ParserChain, x::AbstractString; kw...) = _parse_chain(chain, x; kw...)
Strategy.parse(chain::ParserChain, x::Vector{UInt8}; kw...) = _parse_chain(chain, x; kw...)

function _parser_stage_vector(chain::ParserChain, stage::Symbol)
    if stage === :preprocess
        return chain.preprocess
    elseif stage === :normalize
        return chain.normalize
    elseif stage === :pre_transform
        return chain.pre_transform
    elseif stage === :transform
        return chain.transform
    elseif stage === :post_transform
        return chain.post_transform
    elseif stage === :finalize
        return chain.finalize
    else
        throw(ArgumentError("Unknown parser stage: $(stage)"))
    end
end

function Serde.append_stage!(chain::ParserChain, stage::Symbol, f::Function)
    if stage === :decode
        chain.decode = _par_coerce_parser(f)
    else
        push!(_parser_stage_vector(chain, stage), f)
    end
    return chain
end

function Serde.replace_stage!(chain::ParserChain, stage::Symbol, fs)
    if stage === :decode
        chain.decode = _par_coerce_parser(fs isa AbstractParserStrategy ? fs : (fs isa Function ? fs : first(fs)))
    elseif stage in (:preprocess, :normalize, :pre_transform, :transform, :post_transform, :finalize)
        setfield!(chain, stage, _par_as_stage_vector(fs))
    else
        throw(ArgumentError("Unknown parser stage: $(stage)"))
    end
    return chain
end
