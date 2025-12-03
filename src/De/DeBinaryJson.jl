module DeBinaryJson

using ..ParBinaryJson
using ..Strategy
import ..to_deser

export deser_binaryjson

function deser_binaryjson(::Type{T}, x; kw...) where {T}
    return to_deser(T, parse_binaryjson(x; kw...))
end

deser_binaryjson(::Type{Nothing}, _) = nothing
deser_binaryjson(::Type{Missing}, _) = missing

function deser_binaryjson(f::Function, x; kw...)
    object = parse_binaryjson(x; kw...)
    return to_deser(f(object), object)
end

function deser_binaryjson(::Type{T}, parser::Strategy.AbstractParserStrategy, x; kw...) where {T}
    return to_deser(T, Strategy.parse(parser, x; kw...))
end

end
