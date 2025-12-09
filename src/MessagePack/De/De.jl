module MessagePackDe

using ..Strategy
using ..Serde
using ..MessagePackPar: parse_messagepack

to_deser(::Type{T}, x) where {T} = Serde.deser(T, x)
to_deser(::Type{Nothing}, x) = nothing
to_deser(::Type{Missing}, x) = missing

import .....DeserError, .....DeserSyntaxError, .....WrongType, .....ParamError

export deser_messagepack

function deser_messagepack(::Type{T}, x; kw...) where {T}
    return to_deser(T, parse_messagepack(x; kw...))
end

deser_messagepack(::Type{Nothing}, _) = nothing
deser_messagepack(::Type{Missing}, _) = missing

function deser_messagepack(f::Function, x; kw...)
    object = parse_messagepack(x; kw...)
    return to_deser(f(object), object)
end

function deser_messagepack(::Type{T}, parser::Strategy.AbstractParserStrategy, x; kw...) where {T}
    return to_deser(T, Strategy.parse(parser, x; kw...))
end

end