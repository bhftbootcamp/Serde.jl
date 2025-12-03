module DeBinaryStream

using ..ParBinaryStream
using ..Strategy

export deser_binarystream

function deser_binarystream(::Type{T}, x; kw...) where {T}
    return parse_binarystream(T, x; kw...)
end

deser_binarystream(::Type{Nothing}, _) = nothing
deser_binarystream(::Type{Missing}, _) = missing

function deser_binarystream(f::Function, ::Type{T}, x; kw...) where {T}
    value = parse_binarystream(T, x; kw...)
    return f(value)
end

function deser_binarystream(::Type{T}, parser::Strategy.AbstractParserStrategy, x; kw...) where {T}
    return Strategy.parse(parser, T, x; kw...)
end

end
