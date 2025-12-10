export ParserPipeline, parser_pipeline, @parser_pipeline

using ..Serde
using ..Strategy

const ParseStep = Union{Function, Strategy.AbstractParserStrategy}

struct ParserPipeline{T<:Tuple} <: Strategy.AbstractParserStrategy
    steps::T
end

ParserPipeline(steps::ParseStep...) = parser_pipeline(steps...)

parser_pipeline(steps::ParseStep...) = ParserPipeline(steps)
parser_pipeline(pipe::ParserPipeline, steps::ParseStep...) = ParserPipeline((pipe.steps..., steps...))

function _parser_call_step(step::ParseStep, value, kw::NamedTuple)
    if step isa Strategy.AbstractParserStrategy
        if isempty(kw)
            return Strategy.parse(step, value)
        end
        try
            return Strategy.parse(step, value; kw...)
        catch e
            if e isa MethodError || (e isa Serde.DeserSyntaxError && e.exception isa MethodError)
                return Strategy.parse(step, value)
            else
                rethrow()
            end
        end
    else
        return Strategy._call_stage(step, value, kw)
    end
end

function _parse_pipeline(pipe::ParserPipeline, input; kw...)
    kw_nt = (; kw...)
    result = input
    for step in pipe.steps
        result = _parser_call_step(step, result, kw_nt)
    end
    return result
end

Strategy.parse(pipe::ParserPipeline, x; kw...) = _parse_pipeline(pipe, x; kw...)
Strategy.parse(pipe::ParserPipeline, x::AbstractString; kw...) = _parse_pipeline(pipe, x; kw...)
Strategy.parse(pipe::ParserPipeline, x::Vector{UInt8}; kw...) = _parse_pipeline(pipe, x; kw...)

function _collect_steps(block)
    if block isa Expr && block.head == :block
        return [stmt for stmt in block.args if !(stmt isa LineNumberNode)]
    else
        return [block]
    end
end

macro parser_pipeline(block)
    steps = _collect_steps(block)
    return esc(:(parser_pipeline($(steps...))))
end
