module Serde

function deser end
function parse_value end

# Ser
export to_json,
    to_pretty_json,
    to_csv,
    to_query,
    to_toml,
    to_xml,
    to_yaml

# De
export deser_json,
    deser_csv,
    deser_query,
    deser_toml,
    deser_xml,
    deser_yaml

# Par
export parse_json,
    parse_csv,
    parse_query,
    parse_toml,
    parse_xml,
    parse_yaml

# Utl
export @serde,
    @serde_pascal_case,
    @serde_camel_case,
    @serde_kebab_case,
    to_flatten

include("Utl/Utl.jl")
include("Ser/Ser.jl")
include("De/De.jl")

include("API.jl")
using .API
import .API: SerdeExtensionError,
    parse,
    if_module,
    to_symbol,
    to_string,
    from_string

include("Formats/JSON.jl")
using .JSON
include("Formats/CSV.jl")
using .CSV
include("Formats/TOML.jl")
using .TOML
include("Formats/XML.jl")
using .XML
include("Formats/YAML.jl")
using .YAML
include("Formats/Query/Query.jl")
using .Query

end
