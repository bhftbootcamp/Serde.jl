module ParQuery

import ...Serde

function cut(s::AbstractString, sep::AbstractString)
    index = findfirst(sep, s)
    return if !isnothing(index)
        s[begin:index[1]-1], s[index[1]+length(sep):end]
    else
        (s, "")
    end
end

function unescape(q::AbstractString)::AbstractString
    q = replace(q, '+' => ' ')
    occursin("%", q) || return q
    out = IOBuffer()
    io = IOBuffer(q)
    while !eof(io)
        c = read(io, Char)
        if c == '%'
            c1 = ""
            c = ""
            # Convert a pair of characters (c1, c) representing a hexadecimal value into its corresponding UInt8 value
            # and write it to the specified output stream 'out'.
            # The 'base=16' argument indicates that the conversion should be performed in base 16 (hexadecimal).
            try
                c1 = read(io, Char)
                c = read(io, Char)
                write(out, Base.parse(UInt8, string(c1, c); base = 16))
            catch
                throw(Serde.Query.EscapeError("invalid Query escape '%$c1$c'"))
            end
        else
            write(out, c)
        end
    end
    return String(take!(out))
end

function decode_key(k::AbstractString)::AbstractString
    return try
        unescape(k)
    catch e
        throw(e)
    end
end

function validate_key(k::AbstractString)::Nothing
    contains(k, ';') &&
        throw(Serde.Query.QueryParsingError("invalid semicolon separator in query key"))
    return nothing
end

function decode_value(v::AbstractString)::AbstractString
    return try
        unescape(v)
    catch e
        throw(e)
    end
end

function parse_value(
    ::Type{StructType},
    ::Type{Union{Nothing,FieldType}},
    value::D,
) where {StructType<:Any,FieldType<:Any,D<:Any}
    return parse_value(StructType, FieldType, value)
end

function parse_value(
    ::Type{StructType},
    ::Type{Union{Missing,FieldType}},
    value::D,
) where {StructType<:Any,FieldType<:Any,D<:Any}
    return parse_value(StructType, FieldType, value)
end

function parse_value(::Type{StructType}, ::Type{FieldType}, value::D) where {StructType<:Any,FieldType<:Any,D<:Any}
    return value
end

function parse_value(
    ::Type{StructType},
    ::Type{FieldType},
    value::D,
) where {StructType<:Any,FieldType<:AbstractVector,D<:Any}
    return String.([m.match for m in eachmatch(r"[^\s\[\],]+", value)])
end

function parse_value(
    ::Type{StructType},
    ::Type{FieldType},
    value::D,
) where {StructType<:Any,FieldType<:AbstractSet,D<:Any}
    return String.([m.match for m in eachmatch(r"[^\s\[\],]+", value)])
end

function parse(
    query::AbstractString;
    delimiter::AbstractString = "&",
    dict_type::Type{D} = Dict{String,Any},
) where {D<:AbstractDict}
    parts = split(query, delimiter)
    parsed = D()
    for part in parts
        key, value = cut(part, "=")
        if isempty(key)
            continue
        end
        key = decode_key(key)
        validate_key(key)
        value = decode_value(value)
        if haskey(parsed, key)
            push!(parsed[key], value)
        else
            parsed[key] = [value]
        end
    end
    return parsed
end

function Serde.parse(
    ext::Val{:Serde_Query},
    x::S;
    backbone::Type = Nothing,
    dict_type::Type{D} = Dict{String,Any},
    kw...,
) where {S<:AbstractString,D<:AbstractDict}
    return try
        parsed = ParQuery.parse(x; dict_type = dict_type, kw...)
        for (key, value) in parsed
            value = length(value) == 1 ? value[begin] : value
            if backbone != Nothing
                value = parse_value(backbone, fieldtype(backbone, Symbol(key)), value)
            end
            parsed[key] = value
        end
        parsed
    catch e
        throw(Serde.Query.QuerySyntaxError("invalid Query syntax", e))
    end
end

function Serde.parse(ext::Val{:Serde_Query}, x::Vector{UInt8}; kw...)
    return Serde.parse(ext, unsafe_string(pointer(x), length(x)); kw...)
end

end
