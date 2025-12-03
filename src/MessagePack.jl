module MessagePack

export MsgPackSerializer, MsgPackError

using Dates

struct MsgPackSerializer
    io::IO

    MsgPackSerializer(x::IO) = new(x)
    MsgPackSerializer() = MsgPackSerializer(IOBuffer())
end

Base.close(s::MsgPackSerializer) = close(s.io)
Base.eof(s::MsgPackSerializer) = eof(s.io)
Base.read(s::MsgPackSerializer, x) = read(s.io, x)
Base.write(s::MsgPackSerializer, x) = write(s.io, x)
Base.seek(s::MsgPackSerializer, p::Integer) = seek(s.io, p)
Base.seekstart(s::MsgPackSerializer) = seekstart(s.io)
Base.seekend(s::MsgPackSerializer) = seekend(s.io)
Base.peek(s::MsgPackSerializer) = peek(s.io)

struct MsgPackError <: Exception
    message::String
end

Base.show(io::IO, x::MsgPackError) = print(io, x.message)

const POSITIVE_FIXINT_MIN = 0x00
const POSITIVE_FIXINT_MAX = 0x7F
const FIXMAP_MIN = 0x80
const FIXMAP_MAX = 0x8F
const FIXARRAY_MIN = 0x90
const FIXARRAY_MAX = 0x9F
const FIXSTR_MIN = 0xA0
const FIXSTR_MAX = 0xBF
const NIL = 0xC0
const FALSE = 0xC2
const TRUE = 0xC3
const BIN8 = 0xC4
const BIN16 = 0xC5
const BIN32 = 0xC6
const EXT8 = 0xC7
const EXT16 = 0xC8
const EXT32 = 0xC9
const FLOAT32 = 0xCA
const FLOAT64 = 0xCB
const UINT8 = 0xCC
const UINT16 = 0xCD
const UINT32 = 0xCE
const UINT64 = 0xCF
const INT8 = 0xD0
const INT16 = 0xD1
const INT32 = 0xD2
const INT64 = 0xD3
const FIX_EXT1 = 0xD4
const FIX_EXT2 = 0xD5
const FIX_EXT4 = 0xD6
const FIX_EXT8 = 0xD7
const FIX_EXT16 = 0xD8
const STR8 = 0xD9
const STR16 = 0xDA
const STR32 = 0xDB
const ARRAY16 = 0xDC
const ARRAY32 = 0xDD
const MAP16 = 0xDE
const MAP32 = 0xDF
const NEGATIVE_FIXINT_MIN = 0xE0
const NEGATIVE_FIXINT_MAX = 0xFF

Base.@pure ismsgtype(T::Type{<:Integer})::Bool = true
Base.@pure ismsgtype(T::Type{<:AbstractFloat})::Bool = true
Base.@pure ismsgtype(T::Type{<:Bool})::Bool = true
Base.@pure ismsgtype(T::Type{<:Nothing})::Bool = true
Base.@pure ismsgtype(T::Type{<:AbstractString})::Bool = true
Base.@pure ismsgtype(T::Type{<:AbstractVector})::Bool = true
Base.@pure ismsgtype(T::Type{<:AbstractDict})::Bool = true
Base.@pure ismsgtype(T::Type{<:DateTime})::Bool = true
Base.@pure ismsgtype(T)::Bool = false

include("MessagePack/serialize.jl")
include("MessagePack/deserialize.jl")

end
