# __ serialize

function serialize(s::MsgPackSerializer, x::Integer)
    nb::Int = 0
    if POSITIVE_FIXINT_MIN ≤ x ≤ POSITIVE_FIXINT_MAX
        nb += write(s, UInt8(x))
    elseif 0 ≤ x ≤ typemax(UInt8)
        nb += write(s, UINT8)
        nb += write(s, UInt8(x))
    elseif typemin(Int8) ≤ x ≤ typemax(Int8)
        nb += write(s, INT8)
        nb += write(s, Int8(x))
    elseif 0 ≤ x ≤ typemax(UInt16)
        nb += write(s, UINT16)
        nb += write(s, hton(UInt16(x)))
    elseif typemin(Int16) ≤ x ≤ typemax(Int16)
        nb += write(s, INT16)
        nb += write(s, hton(Int16(x)))
    elseif 0 ≤ x ≤ typemax(UInt32)
        nb += write(s, UINT32)
        nb += write(s, hton(UInt32(x)))
    elseif typemin(Int32) ≤ x ≤ typemax(Int32)
        nb += write(s, INT32)
        nb += write(s, hton(Int32(x)))
    elseif 0 ≤ x ≤ typemax(UInt64)
        nb += write(s, UINT64)
        nb += write(s, hton(UInt64(x)))
    elseif typemin(Int64) ≤ x ≤ typemax(Int64)
        nb += write(s, INT64)
        nb += write(s, hton(Int64(x)))
    else
        throw(MsgPackError("Invalid `Integer` type: $(typeof(x))"))
    end
    return nb
end

function serialize(s::MsgPackSerializer, x::Float32)
    nb::Int = 0
    nb += write(s, FLOAT32)
    nb += write(s, hton(x))
    return nb
end

function serialize(s::MsgPackSerializer, x::Float64)
    nb::Int = 0
    nb += write(s, FLOAT64)
    nb += write(s, hton(x))
    return nb
end

function serialize(s::MsgPackSerializer, x::Bool)
    return write(s, x ? TRUE : FALSE)
end

function serialize(s::MsgPackSerializer, ::Nothing)
    return write(s, NIL)
end

function serialize(s::MsgPackSerializer, x::AbstractString)
    len = ncodeunits(x)
    nb::Int = 0
    if len ≤ (FIXSTR_MAX - FIXSTR_MIN)
        nb += write(s, FIXSTR_MIN | UInt8(len))
    elseif len ≤ typemax(UInt8)
        nb += write(s, STR8)
        nb += write(s, UInt8(len))
    elseif len ≤ typemax(UInt16)
        nb += write(s, STR16)
        nb += write(s, hton(UInt16(len)))
    elseif len ≤ typemax(UInt32)
        nb += write(s, STR32)
        nb += write(s, hton(UInt32(len)))
    else
        throw(MsgPackError("Invalid `String` length: $len"))
    end
    nb += write(s, x)
    return nb
end

function serialize(s::MsgPackSerializer, x::AbstractVector{UInt8})
    len = length(x)
    nb::Int = 0
    if len ≤ typemax(UInt8)
        nb += write(s, BIN8)
        nb += write(s, UInt8(len))
    elseif len ≤ typemax(UInt16)
        nb += write(s, BIN16)
        nb += write(s, hton(UInt16(len)))
    elseif len ≤ typemax(UInt32)
        nb += write(s, BIN32)
        nb += write(s, hton(UInt32(len)))
    else
        throw(MsgPackError("Invalid `Vector{UInt8}` length: $len"))
    end
    nb += write(s, x)
    return nb
end

function serialize(s::MsgPackSerializer, x::AbstractVector)
    len = length(x)
    nb::Int = 0
    if len ≤ (FIXARRAY_MAX - FIXARRAY_MIN)
        nb += write(s, FIXARRAY_MIN | UInt8(len))
    elseif len ≤ typemax(UInt16)
        nb += write(s, ARRAY16)
        nb += write(s, hton(UInt16(len)))
    elseif len ≤ typemax(UInt32)
        nb += write(s, ARRAY32)
        nb += write(s, hton(UInt32(len)))
    else
        throw(MsgPackError("Invalid `Vector` length: $len"))
    end
    for v in x
        nb += serialize(s, v)
    end
    return nb
end

function serialize(s::MsgPackSerializer, x::AbstractDict)
    len = length(x)
    nb::Int = 0
    if len ≤ (FIXMAP_MAX - FIXMAP_MIN)
        nb += write(s, FIXMAP_MIN | UInt8(len))
    elseif len ≤ typemax(UInt16)
        nb += write(s, MAP16)
        nb += write(s, hton(UInt16(len)))
    elseif len ≤ typemax(UInt32)
        nb += write(s, MAP32)
        nb += write(s, hton(UInt32(len)))
    else
        throw(MsgPackError("Invalid `Map` length: $len"))
    end
    for (k, v) in x
        nb += serialize(s, k)
        nb += serialize(s, v)
    end
    return nb
end

function serialize(s::MsgPackSerializer, x::DateTime)
    nb::Int = 0
    epoch = DateTime(1970, 1, 1)
    seconds = Dates.value(x - epoch) ÷ 1000
    nanoseconds = (Dates.value(x - epoch) % 1000) * 1_000_000
    if seconds >= 0 && seconds ≤ typemax(UInt32) && nanoseconds == 0
        nb += write(s, 0xd6)
        nb += write(s, UInt8(0xff))
        nb += write(s, hton(UInt32(seconds)))
    elseif seconds >= 0 && seconds ≤ (1 << 34) - 1
        ts64 = (UInt64(nanoseconds) << 34) | UInt64(seconds)
        nb += write(s, 0xd7)
        nb += write(s, UInt8(0xff))
        nb += write(s, hton(UInt64(ts64)))
    else
        nb += write(s, 0xc7)
        nb += write(s, UInt8(12))
        nb += write(s, UInt8(0xff))
        nb += write(s, hton(UInt32(nanoseconds)))
        nb += write(s, hton(Int64(seconds)))
    end
    return nb
end

function serialize(s::MsgPackSerializer, @nospecialize(x))
    T = typeof(x)::DataType
    ismsgtype(T) && return serialize(s, x)
    nb::Int = 0
    len = nfields(x)
    if len ≤ (FIXMAP_MAX - FIXMAP_MIN)
        nb += write(s.io, FIXMAP_MIN | UInt8(len))
    elseif len ≤ typemax(UInt16)
        nb += write(s.io, MAP16)
        nb += write(s.io, hton(UInt16(len)))
    elseif len ≤ typemax(UInt32)
        nb += write(s.io, MAP32)
        nb += write(s.io, hton(UInt32(len)))
    else
        throw(MsgPackError("Invalid `$(T)` length: $len"))
    end
    for i = 1:len
        nb += serialize(s, string(fieldname(T, i)))
        nb += serialize(s, getfield(x, i))
    end
    return nb
end

