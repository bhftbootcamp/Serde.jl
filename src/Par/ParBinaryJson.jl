module ParBinaryJson

export parse_binaryjson

using ..BinaryJson
using ..Strategy
import ..BinaryJsonParsingStrategy
import ..default_binaryjson_strategy

function parse_binaryjson end

function parse_binaryjson(x::AbstractVector{<:Integer}; strategy::BinaryJsonParsingStrategy = default_binaryjson_strategy(), kw...)
    return strategy.parser(x; kw...)
end

function parse_binaryjson(x::IO; strategy::BinaryJsonParsingStrategy = default_binaryjson_strategy(), kw...)
    return strategy.parser(x; kw...)
end

function parse_binaryjson(x::BinaryJson.BsonSerializer; strategy::BinaryJsonParsingStrategy = default_binaryjson_strategy(), kw...)
    return strategy.parser(x; kw...)
end

end
