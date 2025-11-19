module Strategy

export AbstractParserStrategy,
       AbstractSerializerStrategy,
       parse,
       serialize
export Custom
abstract type AbstractParserStrategy end

function parse(::AbstractParserStrategy, ::AbstractString; kw...)
    throw(MethodError(parse, (:AbstractParserStrategy, :AbstractString)))
end

function parse(s::AbstractParserStrategy, x::Vector{UInt8}; kw...)
    return parse(s, unsafe_string(pointer(x), length(x)); kw...)
end

abstract type AbstractSerializerStrategy end

function serialize(::AbstractSerializerStrategy, data; kw...)
    throw(MethodError(serialize, (:AbstractSerializerStrategy, typeof(data))))
end

end



