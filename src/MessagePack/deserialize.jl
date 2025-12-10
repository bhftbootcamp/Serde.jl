# __ deserialize

function deserialize(s::MsgPackSerializer, ::Type{T})::T where {T<:Integer}
    b = read(s, UInt8)
    if b <= POSITIVE_FIXINT_MAX
        Int8(b)
    elseif b == UINT8
        read(s, UInt8)
    elseif b == UINT16
        ntoh(read(s, UInt16))
    elseif b == UINT32
        ntoh(read(s, UInt32))
    elseif b == UINT64
        ntoh(read(s, UInt64))
    elseif b == INT8
        read(s, Int8)
    elseif b == INT16
        ntoh(read(s, Int16))
    elseif b == INT32
        ntoh(read(s, Int32))
    elseif b == INT64
        ntoh(read(s, Int64))
    else
        throw(MsgPackError("Invalid `Integer` format byte: 0x$(string(b, base = 16))"))
    end
end

function deserialize(s::MsgPackSerializer, ::Type{T})::T where {T<:AbstractFloat}
    b = read(s, UInt8)
    if b == FLOAT32
        ntoh(read(s, Float32))
    elseif b == FLOAT64
        ntoh(read(s, Float64))
    else
        throw(MsgPackError("Invalid `Float` format byte: 0x$(string(b, base = 16))"))
    end
end

function deserialize(s::MsgPackSerializer, ::Type{T})::T where {T<:Bool}
    b = read(s, UInt8)
    if b == FALSE
        false
    elseif b == TRUE
        true
    else
        throw(MsgPackError("Invalid `Boolean` format byte: 0x$(string(b, base = 16))"))
    end
end

function deserialize(s::MsgPackSerializer, ::Type{T})::T where {T<:Nothing}
    if read(s, UInt8) == NIL
        nothing
    else
        throw(MsgPackError("Invalid `Nil` format byte"))
    end
end

function deserialize(s::MsgPackSerializer, ::Type{T})::T where {T<:AbstractString}
    b = read(s, UInt8)
    len = if FIXSTR_MIN <= b <= FIXSTR_MAX
        b & 0x1F
    elseif b == STR8
        read(s, UInt8)
    elseif b == STR16
        ntoh(read(s, UInt16))
    elseif b == STR32
        ntoh(read(s, UInt32))
    else
        throw(MsgPackError("Invalid `String` format byte: 0x$(string(b, base = 16))"))
    end
    return String(read(s, len))
end

function deserialize(s::MsgPackSerializer, ::Type{T})::T where {T<:AbstractVector{<:UInt8}}
    b = read(s, UInt8)
    len = if b == BIN8
        read(s, UInt8)
    elseif b == BIN16
        ntoh(read(s, UInt16))
    elseif b == BIN32
        ntoh(read(s, UInt32))
    else
        throw(MsgPackError("Invalid `Binary` format byte: 0x$(string(b, base = 16))"))
    end
    return read(s, len)
end

function deserialize(s::MsgPackSerializer, ::Type{T})::T where {T<:AbstractVector}
    b = read(s, UInt8)
    len = if FIXARRAY_MIN <= b <= FIXARRAY_MAX
        b & 0x0F
    elseif b == ARRAY16
        ntoh(read(s, UInt16))
    elseif b == ARRAY32
        ntoh(read(s, UInt32))
    else
        throw(MsgPackError("Invalid `Array` format byte: 0x$(string(b, base = 16))"))
    end
    arr = T(undef, len)
    elt = eltype(T)
    for i = 1:len
        arr[i] = deserialize(s, elt)
    end
    return arr
end

function deserialize(s::MsgPackSerializer, ::Type{T})::T where {T<:AbstractDict}
    b = read(s, UInt8)
    len = if FIXMAP_MIN <= b <= FIXMAP_MAX
        b & 0x0F
    elseif b == MAP16
        ntoh(read(s, UInt16))
    elseif b == MAP32
        ntoh(read(s, UInt32))
    else
        throw(MsgPackError("Invalid `Map` format byte: 0x$(string(b, base = 16))"))
    end
    dict = T()
    keyt = keytype(T)
    valt = valtype(T)
    for _ = 1:len
        k = deserialize(s, keyt)
        v = deserialize(s, valt)
        dict[k] = v
    end
    return dict
end

function deserialize(s::MsgPackSerializer, ::Type{T})::T where {T<:DateTime}
    b = read(s, UInt8)
    if b == FIX_EXT4
        read(s, UInt8)
        seconds = ntoh(read(s, UInt32))
        DateTime(1970, 1, 1) + Second(seconds)
    elseif b == FIX_EXT8
        read(s, UInt8)
        ts64 = ntoh(read(s, UInt64))
        nanoseconds = ts64 >> 34
        seconds = ts64 & (UInt64(1) << 34 - 1)
        DateTime(1970, 1, 1) + Second(seconds) + Nanosecond(nanoseconds)
    elseif b == EXT8
        len = read(s, UInt8)
        read(s, UInt8)
        nanoseconds = ntoh(read(s, UInt32))
        seconds = ntoh(read(s, Int64))
        DateTime(1970, 1, 1) + Second(seconds) + Nanosecond(nanoseconds)
    else
        throw(MsgPackError("Invalid `DateTime` format byte: 0x$(string(b, base = 16))"))
    end
end

function deserialize(s::MsgPackSerializer, ::Type{Any})
    b = peek(s)
    if b <= POSITIVE_FIXINT_MAX ||
       b == UINT8 || b == UINT16 || b == UINT32 || b == UINT64 ||
       b == INT8  || b == INT16  || b == INT32  || b == INT64
        deserialize(s, Integer)
    elseif FIXMAP_MIN <= b <= FIXMAP_MAX || b == MAP16 || b == MAP32
        deserialize(s, Dict{Any,Any})
    elseif FIXARRAY_MIN <= b <= FIXARRAY_MAX || b == ARRAY16 || b == ARRAY32
        deserialize(s, Vector{Any})
    elseif FIXSTR_MIN <= b <= FIXSTR_MAX || b == STR8 || b == STR16 || b == STR32
        deserialize(s, AbstractString)
    elseif b == NIL
        deserialize(s, Nothing)
    elseif b == FALSE || b == TRUE
        deserialize(s, Bool)
    elseif b == FLOAT32 || b == FLOAT64
        deserialize(s, AbstractFloat)
    elseif b == BIN8 || b == BIN16 || b == BIN32
        deserialize(s, AbstractVector{UInt8})
    elseif b == FIX_EXT4 || b == FIX_EXT8 || b == EXT8
        deserialize(s, DateTime)
    else
        throw(MsgPackError("Unknown `MessagePack` format byte: 0x$(string(b, base = 16))"))
    end
end

deserialize(s::MsgPackSerializer) = deserialize(s, Any)

function deserialize(s::MsgPackSerializer, @nospecialize(T))
    ismsgtype(T) && return deserialize(s, T)
    b = read(s, UInt8)
    len = if FIXMAP_MIN <= b <= FIXMAP_MAX
        b & 0x0F
    elseif b == MAP16
        ntoh(read(s, UInt16))
    elseif b == MAP32
        ntoh(read(s, UInt32))
    else
        throw(MsgPackError("Invalid `$T` format byte: 0x$(string(b, base = 16))"))
    end
    N = fieldcount(T)
    constructor = (args...) -> T(args...)
    Base.@nexprs 32 i -> begin
        F_i = fieldtype(T, i)
        _ = deserialize(s, String)
        x_i = deserialize(s, F_i)
        N == i && return Base.@ncall i constructor x
    end
    others = Any[]
    for i = 33:N
        F_i = fieldtype(T, i)
        _ = deserialize(s, String)
        push!(others, deserialize(s, F_i))
    end
    return constructor(x_1, x_2, x_3, x_4, x_5, x_6, x_7, x_8, x_9, x_10, x_11, x_12, x_13,
                       x_14, x_15, x_16, x_17, x_18, x_19, x_20, x_21, x_22, x_23, x_24, x_25,
                       x_26, x_27, x_28, x_29, x_30, x_31, x_32, others...)
end


