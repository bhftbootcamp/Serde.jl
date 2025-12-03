module ParBinaryStream

export parse_binarystream

using ..BinaryStream
using ..Strategy
import ..BinaryStreamParsingStrategy
import ..default_binarystream_strategy

function parse_binarystream end

function parse_binarystream(::Type{T}, x; strategy::BinaryStreamParsingStrategy = default_binarystream_strategy(), kw...) where {T}
    return strategy.parser(T, x; kw...)
end

end
