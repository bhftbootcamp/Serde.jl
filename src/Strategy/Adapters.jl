using ..ParJson
using ..ParToml
using ..ParYaml
using ..ParXml
using ..ParCsv
using ..ParQuery
using ..SerJson
using ..SerToml
using ..SerYaml
using ..SerQuery
using ..SerCsv
using ..SerXml
import ..ParJson: parse_json
import ..ParToml: parse_toml
import ..ParYaml: parse_yaml
import ..ParXml: parse_xml
import ..ParCsv: parse_csv
import ..ParQuery: parse_query
import ..SerJson: to_json, to_pretty_json
import ..SerToml: to_toml
import ..SerYaml: to_yaml
import ..SerQuery: to_query
import ..SerCsv: to_csv
import ..SerXml: to_xml

struct JsonParser <: AbstractParserStrategy end
struct TomlParser <: AbstractParserStrategy end
struct YamlParser <: AbstractParserStrategy end
struct XmlParser <: AbstractParserStrategy end
struct CsvParser <: AbstractParserStrategy end
struct QueryParser <: AbstractParserStrategy end

parse(::JsonParser, x::AbstractString; kw...) = ParJson.parse_json(x; kw...)
parse(::TomlParser, x::AbstractString; kw...) = ParToml.parse_toml(x; kw...)
parse(::YamlParser, x::AbstractString; kw...) = ParYaml.parse_yaml(x; kw...)
parse(::XmlParser, x::AbstractString; kw...) = ParXml.parse_xml(x; kw...)
parse(::CsvParser, x::AbstractString; kw...) = ParCsv.parse_csv(x; kw...)
parse(::QueryParser, x::AbstractString; kw...) = ParQuery.parse_query(x; kw...)

parse_json(parser::AbstractParserStrategy, x; kw...) = parse(parser, x; kw...)
parse_toml(parser::AbstractParserStrategy, x; kw...) = parse(parser, x; kw...)
parse_yaml(parser::AbstractParserStrategy, x; kw...) = parse(parser, x; kw...)
parse_xml(parser::AbstractParserStrategy, x; kw...) = parse(parser, x; kw...)
parse_csv(parser::AbstractParserStrategy, x; kw...) = parse(parser, x; kw...)
parse_query(parser::AbstractParserStrategy, x; kw...) = parse(parser, x; kw...)

struct JsonSerializer <: AbstractSerializerStrategy
    pretty::Bool
end
JsonSerializer(; pretty::Bool = false) = JsonSerializer(pretty)

struct TomlSerializer <: AbstractSerializerStrategy end
struct YamlSerializer <: AbstractSerializerStrategy end
struct QuerySerializer <: AbstractSerializerStrategy end
struct CsvSerializer <: AbstractSerializerStrategy end
struct XmlSerializer <: AbstractSerializerStrategy end

function serialize(s::JsonSerializer, data; kw...)
    return s.pretty ? SerJson.to_pretty_json(data; kw...) : SerJson.to_json(data; kw...)
end

function serialize(s::JsonSerializer, f::Function, data; kw...)
    return s.pretty ? SerJson.to_pretty_json(f, data; kw...) : SerJson.to_json(f, data; kw...)
end

serialize(::TomlSerializer, data; kw...) = SerToml.to_toml(data; kw...)
serialize(::YamlSerializer, data; kw...) = SerYaml.to_yaml(data; kw...)
serialize(::YamlSerializer, f::Function, data; kw...) = SerYaml.to_yaml(f, data; kw...)
serialize(::QuerySerializer, data; kw...) = SerQuery.to_query(data; kw...)
serialize(::CsvSerializer, data::Vector; kw...) = SerCsv.to_csv(data; kw...)
serialize(::XmlSerializer, data; kw...) = SerXml.to_xml(data; kw...)

to_json(s::JsonSerializer, data; kw...) = serialize(s, data; kw...)
to_json(s::JsonSerializer, f::Function, data; kw...) = serialize(s, f, data; kw...)
to_pretty_json(::JsonSerializer, data; kw...) = serialize(JsonSerializer(pretty = true), data; kw...)
to_toml(s::TomlSerializer, data; kw...) = serialize(s, data; kw...)
to_yaml(s::YamlSerializer, data; kw...) = serialize(s, data; kw...)
to_yaml(s::YamlSerializer, f::Function, data; kw...) = serialize(s, f, data; kw...)
to_query(s::QuerySerializer, data; kw...) = serialize(s, data; kw...)
to_csv(s::CsvSerializer, data::Vector; kw...) = serialize(s, data; kw...)
to_xml(s::XmlSerializer, data; kw...) = serialize(s, data; kw...)


