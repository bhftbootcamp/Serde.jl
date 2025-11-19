module DeXml

using ..ParXml
using ..Strategy
import ..to_deser
import ...DeserError, ...DeserSyntaxError

export deser_xml

function deser_xml(::Type{T}, x; kw...) where {T}
    return to_deser(T, parse_xml(x; kw...))
end

deser_xml(::Type{Nothing}, _) = nothing
deser_xml(::Type{Missing}, _) = missing

function deser_xml(f::Function, x; kw...)
    object = parse_xml(x; kw...)
    return to_deser(f(object), object)
end

function deser_xml(::Type{T}, parser::Strategy.AbstractParserStrategy, x; kw...) where {T}
    return to_deser(T, Strategy.parse(parser, x; kw...))
end

end
