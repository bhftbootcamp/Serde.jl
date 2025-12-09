module MessagePackPar

export parse_messagepack, MessagePackParsingStrategy, default_messagepack_strategy

using .....Serde: MessagePack, AbstractParsingStrategy, DeserSyntaxError

struct MessagePackParsingStrategy <: AbstractParsingStrategy
    parser::Function
end

function default_messagepack_strategy()
    MessagePackParsingStrategy((x; kw...) -> begin
        try
            if x isa MessagePack.MsgPackSerializer
                return MessagePack.deserialize(x)
            elseif x isa IO
                return MessagePack.deserialize(MessagePack.MsgPackSerializer(x))
            else
                bytes = x isa AbstractVector{UInt8} ? x : Vector{UInt8}(x)
                return MessagePack.deserialize(MessagePack.MsgPackSerializer(IOBuffer(bytes)))
            end
        catch e
            throw(DeserSyntaxError("messagepack", "failed to parse MessagePack input", e))
        end
    end)
end

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
