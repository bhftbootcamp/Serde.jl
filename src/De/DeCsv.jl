module DeCsv

using ..ParCsv
using ..Strategy
import ..to_deser
import ...DeserError, ...DeserSyntaxError

export deser_csv

function deser_csv(::Type{T}, x; kw...) where {T}
    return to_deser(Vector{T}, parse_csv(x; kw...))
end

deser_csv(::Type{Nothing}, _) = nothing
deser_csv(::Type{Missing}, _) = missing

function deser_csv(f::Function, x; kw...)
    object = parse_csv(x; kw...)
    return to_deser(f(object), object)
end

function deser_csv(::Type{T}, parser::Strategy.AbstractParserStrategy, x; kw...) where {T}
    return to_deser(Vector{T}, Strategy.parse(parser, x; kw...))
end

end
