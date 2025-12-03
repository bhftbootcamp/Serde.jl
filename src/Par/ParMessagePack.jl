module ParMessagePack

export parse_messagepack

using ..MessagePack
using ..Strategy
import ..MessagePackParsingStrategy
import ..default_messagepack_strategy

function _normalize_messagepack(x)
    if x isa AbstractVector{UInt8}
        return x
    elseif x isa AbstractVector
        return [_normalize_messagepack(v) for v in x]
    elseif x isa AbstractDict
        dict = Dict{String,Any}()
        for (k, v) in x
            dict[string(k)] = _normalize_messagepack(v)
        end
        return dict
    else
        return x
    end
end

function parse_messagepack end

function parse_messagepack(x::AbstractVector{<:Integer}; strategy::MessagePackParsingStrategy = default_messagepack_strategy(), kw...)
    return _normalize_messagepack(strategy.parser(x; kw...))
end

function parse_messagepack(x::IO; strategy::MessagePackParsingStrategy = default_messagepack_strategy(), kw...)
    return _normalize_messagepack(strategy.parser(x; kw...))
end

function parse_messagepack(x::MessagePack.MsgPackSerializer; strategy::MessagePackParsingStrategy = default_messagepack_strategy(), kw...)
    return _normalize_messagepack(strategy.parser(x; kw...))
end

end
