module Serde

using JSON
using CSV
using TOML
using EzXML
using YAML

function deser end
function parse_value end

abstract type DeserError <: Exception end

struct ParamError <: DeserError
    key::Any
end

function Base.show(io::IO, e::ParamError)
    return print(
        io,
        "ParamError: parameter '$(e.key)' was not passed or has the value 'nothing'",
    )
end

struct WrongType <: DeserError
    maintype::DataType
    key::Any
    value::Any
    from_type::Any
    to_type::Any
end

function Base.show(io::IO, e::WrongType)
    return print(
        io,
        "WrongType: for '$(e.maintype)' value '$(e.value)' has wrong type '$(e.key)::$(e.from_type)', must be '$(e.key)::$(e.to_type)'",
    )
end

struct DeserSyntaxError <: DeserError
    format::String
    message::String
    exception::Any
end

function Base.show(io::IO, e::DeserSyntaxError)
    return print(io, "DeserSyntaxError ($(e.format)): $(e.message), caused by: $(e.exception)")
end

function _has_text_content(node)::Bool
    is_content = istext(node) || iscdata(node) || !haselement(node)
    is_empty = isempty(nodecontent(node)) || all(isspace, nodecontent(node))
    return is_content && !is_empty
end

function _parse_xml_node(xml::AbstractString; kw...)
    doc = EzXML.parsexml(xml)
    return _parse_xml_node(root(doc); kw...)
end

function _parse_xml_node(node; dict_type::Type{D}, force_array::Bool) where {D<:AbstractDict}
    xml_dict = D()
    if _has_text_content(node)
        xml_dict["_"] = nodecontent(node)
    end
    for attr in attributes(node)
        xml_dict[nodename(attr)] = nodecontent(attr)
    end
    for child in elements(node)
        child_name = nodename(child)
        child_dict = _parse_xml_node(child; dict_type = dict_type, force_array = force_array)
        if haskey(xml_dict, child_name)
            if force_array || isa(xml_dict[child_name], AbstractVector)
                push!(xml_dict[child_name], child_dict)
            else
                xml_dict[child_name] = [xml_dict[child_name], child_dict]
            end
        else
            xml_dict[child_name] = force_array ? [child_dict] : child_dict
        end
    end
    return xml_dict
end

include("BinaryJson.jl")
include("MessagePack.jl")
include("BinaryStream.jl")

export AbstractParsingStrategy,
    JsonParsingStrategy,
    XmlParsingStrategy,
    YamlParsingStrategy,
    TomlParsingStrategy,
    CsvParsingStrategy,
    QueryParsingStrategy,
    BinaryJsonParsingStrategy,
    MessagePackParsingStrategy,
    BinaryStreamParsingStrategy

abstract type AbstractParsingStrategy end

struct JsonParsingStrategy <: AbstractParsingStrategy
    parser::Function
end

struct XmlParsingStrategy <: AbstractParsingStrategy
    parser::Function
end

struct YamlParsingStrategy <: AbstractParsingStrategy
    parser::Function
end

struct TomlParsingStrategy <: AbstractParsingStrategy
    parser::Function
end

struct CsvParsingStrategy <: AbstractParsingStrategy
    parser::Function
end

struct QueryParsingStrategy <: AbstractParsingStrategy
    parser::Function
end

struct BinaryJsonParsingStrategy <: AbstractParsingStrategy
    parser::Function
end

struct MessagePackParsingStrategy <: AbstractParsingStrategy
    parser::Function
end

struct BinaryStreamParsingStrategy <: AbstractParsingStrategy
    parser::Function
end

function default_json_strategy()
    JsonParsingStrategy((x; kw...) -> begin
        try
            JSON.parse(x; kw...)
        catch e
            throw(DeserSyntaxError("json", "failed to parse JSON input", e))
        end
    end)
end

function default_xml_strategy()
    XmlParsingStrategy((x; dict_type = Dict{String,Any}, force_array::Bool = false, kw...) -> begin
        try
            _parse_xml_node(x; dict_type = dict_type, force_array = force_array, kw...)
        catch e
            throw(DeserSyntaxError("xml", "failed to parse XML input", e))
        end
    end)
end

function default_yaml_strategy()
    YamlParsingStrategy((x; kw...) -> begin
        try
            YAML.load(x; kw...)
        catch e
            throw(DeserSyntaxError("yaml", "failed to parse YAML input", e))
        end
    end)
end

function default_toml_strategy()
    TomlParsingStrategy((x; kw...) -> begin
        try
            TOML.parse(x; kw...)
        catch e
            throw(DeserSyntaxError("toml", "failed to parse TOML input", e))
        end
    end)
end

function default_csv_strategy()
    CsvParsingStrategy((io; kw...) -> begin
        try
            CSV.File(io; types=String, strict=true, kw...) |> CSV.rowtable
        catch e
            throw(DeserSyntaxError("csv", "failed to parse CSV input", e))
        end
    end)
end

function default_query_strategy()
    QueryParsingStrategy((x; dict_type = Dict{String,Any}, kw...) -> begin
        try
            parts = split(x, get(kw, :delimiter, "&"))
            parsed = dict_type()
            for part in parts
                if isempty(part)
                    continue
                end
                key, value = let
                    index = findfirst("=", part)
                    if !isnothing(index)
                        part[begin:index[1]-1], part[index[1]+1:end]
                    else
                        (part, "")
                    end
                end

                if isempty(key)
                    continue
                end
                key = let
                    q = replace(key, '+' => ' ')
                    occursin("%", q) || (q, false)
                    out = IOBuffer()
                    io = IOBuffer(q)
                    try
                        while !eof(io)
                            c = read(io, Char)
                            if c == '%'
                                try
                                    c1 = read(io, Char)
                                    c2 = read(io, Char)
                                    write(out, Base.parse(UInt8, string(c1, c2); base = 16))
                                catch
                                    throw(ArgumentError("invalid Query escape '%$c1$c2'"))
                                end
                            else
                                write(out, c)
                            end
                        end
                        String(take!(out))
                    finally
                        close(io)
                        close(out)
                    end
                end

                value = let
                    q = replace(value, '+' => ' ')
                    occursin("%", q) || (q, false)
                    out = IOBuffer()
                    io = IOBuffer(q)
                    try
                        while !eof(io)
                            c = read(io, Char)
                            if c == '%'
                                try
                                    c1 = read(io, Char)
                                    c2 = read(io, Char)
                                    write(out, Base.parse(UInt8, string(c1, c2); base = 16))
                                catch
                                    throw(ArgumentError("invalid Query escape '%$c1$c2'"))
                                end
                            else
                                write(out, c)
                            end
                        end
                        String(take!(out))
                    finally
                        close(io)
                        close(out)
                    end
                end
                contains(key, ';') && throw(ArgumentError("invalid semicolon separator in query key"))
                if haskey(parsed, key)
                    push!(parsed[key], value)
                else
                    parsed[key] = [value]
                end
            end
            parsed
        catch e
            throw(DeserSyntaxError("query", "failed to parse Query input", e))
        end
    end)
end

function default_binaryjson_strategy()
    BinaryJsonParsingStrategy((x; kw...) -> begin
        try
            if x isa BinaryJson.BsonSerializer
                return BinaryJson.deserialize(x)
            elseif x isa IO
                return BinaryJson.deserialize(BinaryJson.BsonSerializer(x))
            else
                return BinaryJson.deserialize(x)
            end
        catch e
            throw(DeserSyntaxError("binaryjson", "failed to parse BinaryJson input", e))
        end
    end)
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

function _binstream_serializer(x)
    bytes = if x isa BinaryStream.Serializer
        seekstart(x)
        readavailable(x)
    elseif x isa IO
        read(x)
    elseif x isa AbstractVector{<:Integer}
        Vector{UInt8}(x)
    else
        Vector{UInt8}(x)
    end
    buf = IOBuffer(bytes; read = true, write = false)
    seekstart(buf)
    return BinaryStream.Serializer(buf)
end

function _deserialize_binarystream(s::BinaryStream.Serializer, ::Type{T}) where {T}
    return BinaryStream.deserialize(s, T)
end

function default_binarystream_strategy()
    BinaryStreamParsingStrategy((T, x; kw...) -> begin
        try
            serializer = _binstream_serializer(x)
            return _deserialize_binarystream(serializer, T)
        catch e
            throw(DeserSyntaxError("binarystream", "failed to parse BinaryStream input", e))
        end
    end)
end

# Ser
export to_csv,
    to_json,
    to_pretty_json,
    to_query,
    to_toml,
    to_xml,
    to_yaml,
    to_binaryjson,
    to_messagepack,
    to_binarystream

# De
export deser_csv,
    deser_json,
    deser_query,
    deser_toml,
    deser_xml,
    deser_yaml,
    deser_binaryjson,
    deser_messagepack,
    deser_binarystream

# Par
export parse_csv,
    parse_json,
    parse_query,
    parse_toml,
    parse_xml,
    parse_yaml,
    parse_binaryjson,
    parse_messagepack,
    parse_binarystream

# Utl
export @serde,
    @serde_pascal_case,
    @serde_camel_case,
    @serde_kebab_case,
    to_flatten
include("Strategy/Strategy.jl")
include("Utl/Utl.jl")
include("Par/Par.jl")
include("Ser/Ser.jl")
Base.include(Strategy, "Strategy/Adapters.jl")
Base.include(Strategy, "Strategy/Custom.jl")
include("De/De.jl")
end
