module DeYaml

using ..ParYaml
using ..Strategy
import ..to_deser
import ...DeserError, ...DeserSyntaxError

export deser_yaml

function deser_yaml(::Type{T}, x; kw...) where {T}
    return to_deser(T, parse_yaml(x; kw...))
end

deser_yaml(::Type{Nothing}, _) = nothing
deser_yaml(::Type{Missing}, _) = missing

function deser_yaml(f::Function, x; kw...)
    object = parse_yaml(x; kw...)
    return to_deser(f(object), object)
end

function deser_yaml(::Type{T}, parser::Strategy.AbstractParserStrategy, x; kw...) where {T}
    return to_deser(T, Strategy.parse(parser, x; kw...))
end

end
