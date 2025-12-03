module BinaryJson

using Dates

export BsonError, BsonSerializer, serialize, deserialize

struct BsonError <: Exception
    message::String
end

Base.show(io::IO, e::BsonError) = print(io, "BsonError: " * e.message)

struct BsonSerializer
    io::IO
end

BsonSerializer() = BsonSerializer(IOBuffer())

const ZERO = UInt8(0x00)
const FLOAT64 = UInt8(0x01)
const STR = UInt8(0x02)
const DOCUMENT = UInt8(0x03)
const ARRAY = UInt8(0x04)
const BINDATA = UInt8(0x05)
const BOOLEAN = UInt8(0x08)
const DATETIME = UInt8(0x09)
const NIL = UInt8(0x0A)
const REGEXP = UInt8(0x0B)
const INT32 = UInt8(0x10)
const INT64 = UInt8(0x12)

const BINARY_SUBTYPE_GENERIC = UInt8(0x00)

isdigitstring(s::AbstractString) = all(isdigit, s)

Base.close(s::BsonSerializer) = close(s.io)
Base.eof(s::BsonSerializer) = eof(s.io)
Base.seek(s::BsonSerializer, p::Integer) = seek(s.io, p)
Base.seekstart(s::BsonSerializer) = seekstart(s.io)
Base.seekend(s::BsonSerializer) = seekend(s.io)

write_cstring(io::IO, name::AbstractString)::Nothing = (write(io, codeunits(name)); write(io, ZERO); nothing)

function write_length_prefixed!(io::IO, body::Vector{UInt8})
    len = length(body) + 4
    len > typemax(Int32) && throw(BsonError("Invalid document length: $len"))
    write(io, reinterpret(UInt8, [htol(Int32(len))]))
    write(io, body)
    return nothing
end

function write_integer!(io::IO, val::Integer)
    if typemin(Int32) <= val <= typemax(Int32)
        write(io, reinterpret(UInt8, [htol(Int32(val))]))
    else
        write(io, reinterpret(UInt8, [htol(Int64(val))]))
    end
    return nothing
end

function write_string!(io::IO, val::AbstractString)
    bytes = codeunits(String(val))
    len = length(bytes) + 1
    len > typemax(Int32) && throw(BsonError("Invalid string length: $len"))
    write(io, reinterpret(UInt8, [htol(Int32(len))]))
    write(io, bytes)
    write(io, ZERO)
    return nothing
end

function write_binary!(io::IO, bytes::AbstractVector{<:UInt8})
    len = length(bytes)
    len > typemax(Int32) && throw(BsonError("Invalid binary length: $len"))
    write(io, reinterpret(UInt8, [htol(Int32(len))]))
    write(io, BINARY_SUBTYPE_GENERIC)
    write(io, bytes)
    return nothing
end

function regex_options(rx::Regex)::String
    flags = rx.compile_options
    opts = Char[]
    (flags & Base.PCRE.CASELESS) != 0 && push!(opts, 'i')
    (flags & Base.PCRE.MULTILINE) != 0 && push!(opts, 'm')
    (flags & Base.PCRE.DOTALL) != 0 && push!(opts, 's')
    return join(sort(opts))
end

function document_bytes(dict::AbstractDict{K,V}) where {K,V}
    body = IOBuffer()
    for (k, v) in dict
        write_element!(body, string(k), v)
    end
    write(body, ZERO)
    body_bytes = take!(body)
    io = IOBuffer()
    write_length_prefixed!(io, body_bytes)
    return take!(io)
end

function array_bytes(arr)::Vector{UInt8}
    body = IOBuffer()
    for (i, v) in enumerate(arr)
        write_element!(body, string(i - 1), v)
    end
    write(body, ZERO)
    body_bytes = take!(body)
    io = IOBuffer()
    write_length_prefixed!(io, body_bytes)
    return take!(io)
end

function struct_to_dict(val)::Dict{String,Any}
    dict = Dict{String,Any}()
    T = typeof(val)
    Base.isstructtype(T) || throw(BsonError("Unsupported type $(T)"))
    for field in fieldnames(T)
        dict[string(field)] = getfield(val, field)
    end
    return dict
end

function write_document_element!(io::IO, name::AbstractString, dict::AbstractDict)
    write(io, DOCUMENT)
    write_cstring(io, name)
    write(io, document_bytes(dict))
    return nothing
end

function write_array_element!(io::IO, name::AbstractString, arr)
    write(io, ARRAY)
    write_cstring(io, name)
    write(io, array_bytes(arr))
    return nothing
end

function write_struct_element!(io::IO, name::AbstractString, val)
    write_document_element!(io, name, struct_to_dict(val))
end

function write_element!(io::IO, name::AbstractString, val)
    if val isa Symbol
        return write_element!(io, name, String(val))
    elseif val isa Missing
        return write_element!(io, name, nothing)
    elseif val isa Bool
        write(io, BOOLEAN)
        write_cstring(io, name)
        write(io, UInt8(val))
    elseif val isa Nothing
        write(io, NIL)
        write_cstring(io, name)
    elseif val isa Integer
        if typemin(Int32) <= val <= typemax(Int32)
            write(io, INT32)
            write_cstring(io, name)
            write_integer!(io, val)
        else
            write(io, INT64)
            write_cstring(io, name)
            write_integer!(io, val)
        end
    elseif val isa AbstractFloat
        write(io, FLOAT64)
        write_cstring(io, name)
        bits = htol(reinterpret(UInt64, Float64(val)))
        write(io, reinterpret(UInt8, [bits]))
    elseif val isa AbstractString
        write(io, STR)
        write_cstring(io, name)
        write_string!(io, val)
    elseif val isa Dates.DateTime
        write(io, DATETIME)
        write_cstring(io, name)
        ms = Int64(Dates.value(val - Dates.DateTime(1970, 1, 1)))
        write(io, reinterpret(UInt8, [htol(ms)]))
    elseif val isa Regex
        write(io, REGEXP)
        write_cstring(io, name)
        write_cstring(io, val.pattern)
        write_cstring(io, regex_options(val))
    elseif val isa AbstractVector{UInt8}
        write(io, BINDATA)
        write_cstring(io, name)
        write_binary!(io, val)
    elseif val isa AbstractArray
        write_array_element!(io, name, val)
    elseif val isa AbstractDict
        write_document_element!(io, name, val)
    else
        write_struct_element!(io, name, val)
    end
    return nothing
end

function serialize_document(x)::Vector{UInt8}
    return document_bytes(x)
end

function serialize(s::BsonSerializer, data)
    bytes = if data isa AbstractDict
        document_bytes(data)
    elseif data isa AbstractVector{UInt8}
        document_bytes(Dict("data" => data))
    elseif data isa AbstractArray
        array_bytes(data)
    else
        Base.isstructtype(typeof(data)) ? document_bytes(struct_to_dict(data)) : document_bytes(Dict("value" => data))
    end
    write(s.io, bytes)
    return s
end

serialize(data) = (s = BsonSerializer(); serialize(s, data); take!(s.io))

read_cstring(io)::String = begin
    bytes = UInt8[]
    while true
        b = read(io, UInt8)
        b == ZERO && break
        push!(bytes, b)
    end
    return String(bytes)
end

function is_arraylike(dict::Dict{String,Any})::Bool
    isempty(dict) && return true
    keys_list = collect(keys(dict))
    all(isdigitstring, keys_list) || return false
    idxs = sort(parse.(Int, keys_list))
    return idxs == collect(0:(length(dict) - 1))
end

function dict_to_array(dict::Dict{String,Any})
    arr = Vector{Any}(undef, length(dict))
    for (k, v) in dict
        arr[parse(Int, k) + 1] = v
    end
    return arr
end

function read_document(io)::Dict{String,Any}
    _ = ltoh(read(io, Int32))
    dict = Dict{String,Any}()
    while true
        byte = read(io, UInt8)
        byte == ZERO && break
        name = read_cstring(io)
        dict[name] = deserialize_value(io, byte)
    end
    return dict
end

function read_array(io)::Vector{Any}
    _ = ltoh(read(io, Int32))
    values = Any[]
    while true
        byte = read(io, UInt8)
        byte == ZERO && break
        _ = read_cstring(io)
        push!(values, deserialize_value(io, byte))
    end
    return values
end

function deserialize_value(io::IO, byte::UInt8)::Any
    if byte == INT32
        return ltoh(read(io, Int32))
    elseif byte == INT64
        return ltoh(read(io, Int64))
    elseif byte == FLOAT64
        return reinterpret(Float64, ltoh(read(io, UInt64)))
    elseif byte == STR
        len = ltoh(read(io, Int32))
        bytes = read(io, len - 1)
        _ = read(io, UInt8)
        return String(bytes)
    elseif byte == DOCUMENT
        return read_document(io)
    elseif byte == ARRAY
        return read_array(io)
    elseif byte == BINDATA
        len = ltoh(read(io, Int32))
        _ = read(io, UInt8) # subtype
        return read(io, len)
    elseif byte == BOOLEAN
        return Bool(read(io, UInt8))
    elseif byte == DATETIME
        ms = ltoh(read(io, Int64))
        return Dates.DateTime(1970, 1, 1) + Dates.Millisecond(ms)
    elseif byte == NIL
        return nothing
    elseif byte == REGEXP
        pattern = read_cstring(io)
        options = read_cstring(io)
        return Regex(pattern, options)
    else
        throw(BsonError("Unknown BSON type 0x$(string(byte, base = 16))"))
    end
end

maybe_array(x) = x
function maybe_array(dict::Dict{String,Any})
    return is_arraylike(dict) ? dict_to_array(dict) : dict
end

function deserialize(s::BsonSerializer)
    dict = read_document(s.io)
    return maybe_array(dict)
end

function deserialize(x::AbstractVector{<:Integer})
    buf = IOBuffer(collect(UInt8, x))
    return deserialize(BsonSerializer(buf))
end

end
