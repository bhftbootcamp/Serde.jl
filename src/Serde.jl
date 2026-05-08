module Serde

function deser end
function parse_value end

"""
    Serde.DefaultStrategy

Default context singleton used when no explicit context is supplied to `from_*` / `to_*`
functions.

You do not normally need to construct or pass `DefaultStrategy()` directly — it is inserted
automatically. It exists so that trait methods can be dispatched on `::DefaultStrategy` to
define package-wide defaults that differ from the built-in behaviour.

# Examples
```julia
# Apply a custom default deser_name for all types when no context is given:
Serde.deser_name(::Serde.DefaultStrategy, ::Type{T}, ::Val{x}) where {T,x} =
    Symbol(replace(string(x), "_" => "-"))
```

See also: [`CamelCase`](@ref), [`PascalCase`](@ref), [`KebabCase`](@ref).
"""
struct DefaultStrategy end

include("types.jl")
include("traits.jl")
include("ser.jl")
include("deser.jl")
include("cases.jl")
include("with.jl")

include("formats/Json.jl")
using .SerdeJson

include("formats/Toml.jl")
using .SerdeToml

include("formats/Query.jl")
using .SerdeQuery

include("formats/Csv.jl")
using .SerdeCsv

include("formats/MsgPack.jl")
using .SerdeMsgPack

include("formats/Bson.jl")
using .SerdeBson

include("formats/Yaml.jl")
using .SerdeYaml

include("formats/Xml.jl")
using .SerdeXml

export CamelCase, PascalCase, KebabCase, LowerCase
export With

export from_json, from_toml, from_yaml, from_xml, from_csv, from_query, from_msgpack, from_bson

export to_json, to_toml, to_yaml, to_xml, to_csv, to_query, to_msgpack, to_bson
export to_pretty_json

export parse_json, parse_toml, parse_yaml, parse_xml, parse_csv, parse_query, parse_msgpack, parse_bson

export try_from_json, try_from_toml, try_from_yaml, try_from_query, try_from_csv, try_from_msgpack, try_from_bson

export SerdeError, ParseError, DeserError, MissingFieldError, TypeMismatchError, ValidationError

export DefaultStrategy

export register_tagged_subtype

export to_flatten

end
