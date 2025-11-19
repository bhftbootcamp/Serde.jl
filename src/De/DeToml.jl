module DeToml

using ..ParToml
using ..Strategy
import ..to_deser
import ...DeserError, ...DeserSyntaxError

export deser_toml

function deser_toml(::Type{T}, x; kw...) where {T}
    return to_deser(T, parse_toml(x; kw...))
end

deser_toml(::Type{Nothing}, _) = nothing
deser_toml(::Type{Missing}, _) = missing

function deser_toml(f::Function, x; kw...)
    object = parse_toml(x; kw...)
    return to_deser(f(object), object)
end

function deser_toml(::Type{T}, parser::Strategy.AbstractParserStrategy, x; kw...) where {T}
    return to_deser(T, Strategy.parse(parser, x; kw...))
end

end
