module DeQuery

using ..ParQuery
using ..Strategy
import ..to_deser
import ...DeserError, ...DeserSyntaxError

export deser_query

function deser_query(::Type{T}, x; kw...) where {T}
    return to_deser(T, parse_query(x; backbone=T, kw...))
end

deser_query(::Type{Nothing}, _) = nothing
deser_query(::Type{Missing}, _) = missing

function deser_query(f::Function, x; kw...)
    object = parse_query(x; kw...)
    return to_deser(f(object), object)
end

function deser_query(::Type{T}, parser::Strategy.AbstractParserStrategy, x; kw...) where {T}
    return to_deser(T, Strategy.parse(parser, x; backbone=T, kw...))
end

end
