module SerBinaryStream

export to_binarystream

using ..BinaryStream

_read_bytes(s::BinaryStream.Serializer) = take!(s.io)

function to_binarystream(::Type{T}, data::T; kw...) where {T}
    s = BinaryStream.Serializer()
    BinaryStream.serialize(s, T, data)
    return _read_bytes(s)
end

function to_binarystream(data; kw...)
    s = BinaryStream.Serializer()
    BinaryStream.serialize(s, typeof(data), data)
    return _read_bytes(s)
end

function to_binarystream(f::Function, data; kw...)
    value = f(data)
    return to_binarystream(typeof(value), value; kw...)
end

function to_binarystream(::Type{T}, f::Function, data::T; kw...) where {T}
    return to_binarystream(T, f(data); kw...)
end

end
