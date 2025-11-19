module DeJson

using ..ParJson
using ..Strategy
import ..to_deser
import ...DeserError, ...DeserSyntaxError

export deser_json

function deser_json(::Type{T}, x; kw...) where {T}
    return to_deser(T, parse_json(x; kw...))
end

deser_json(::Type{Nothing}, _) = nothing
deser_json(::Type{Missing}, _) = missing

function deser_json(f::Function, x; kw...)
    object = parse_json(x; kw...)
    return to_deser(f(object), object)
end

function deser_json(::Type{T}, parser::Strategy.AbstractParserStrategy, x; kw...) where {T}
    return to_deser(T, Strategy.parse(parser, x; kw...))
end

end
