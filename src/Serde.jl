module Serde

function deser end
function parse_value end

# Ser
export to_json,
    to_pretty_json,
    to_query,
    to_toml,
    to_xml,
    to_csv

# De
export deser_json,
    deser_query,
    deser_toml,
    deser_csv,
    deser_xml

# Par
export parse_json,
    parse_query,
    parse_toml,
    parse_csv,
    parse_xml

# Utl
export @serde,
    to_flatten

include("Utl/Utl.jl")
include("Par/Par.jl")
include("Ser/Ser.jl")
include("De/De.jl")

end
