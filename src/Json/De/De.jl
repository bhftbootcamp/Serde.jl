module JsonDe

using ..Strategy
using ..Serde
using ..JsonPar: parse_json

export deser_json

function deser_json(::Type{T}, x; kw...) where {T}
    return Serde.to_deser(T, parse_json(x; kw...))
end

deser_json(::Type{Nothing}, _) = nothing
deser_json(::Type{Missing}, _) = missing

function deser_json(f::Function, x; kw...)
    object = parse_json(x; kw...)
    return Serde.to_deser(f(object), object)
end

function deser_json(::Type{T}, parser::Strategy.AbstractParserStrategy, x; kw...) where {T}
    return Serde.to_deser(T, Strategy.parse(parser, x; kw...))
end

end
