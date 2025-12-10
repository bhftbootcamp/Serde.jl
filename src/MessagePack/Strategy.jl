module Strategy

using .....Serde: AbstractParsingStrategy, DeserSyntaxError
using .....Serde: MessagePack

export MessagePackParsingStrategy, default_messagepack_strategy

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

end
