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
include("Par/Par.jl")
include("Ser/Ser.jl")
include("De/De.jl")

function to_string end
function to_string(ext::Module, args...; kwargs...)
    to_string(Val(first(fullname(ext))), args...; kwargs...)
end

function from_string end
function from_string(ext::Module, args...; kwargs...)
    from_string(Val(first(fullname(ext))), args...; kwargs...)
end

function parse end
function parse(ext::Module, args...; kwargs...)
    parse(Val(first(fullname(ext))), args...; kwargs...)
end
    
export to_string, from_string, parse

#include("Ext.jl")
include("JSON.jl")
using .JSON
include("CSV.jl")
using .CSV
include("TOML.jl")
using .TOML
include("XML.jl")
using .XML
include("YAML.jl")
using .YAML

end
