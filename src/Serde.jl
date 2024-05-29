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

"""
Exception raised when the module required for an extension is missing.
"""
struct SerdeExtensionError <: Exception
    # This must be a symbol since we cannot instantiate the module object: The
    # module is obviously missing, that's why we want to report it in the first
    # place...
    extension::Symbol
end

function Base.show(io::IO, e::SerdeExtensionError)
    return print(io, """SerdeExtensionError: to use this method, first you need \
    to import the '$(string(e.extension))' module.""")
end

"""
    if_module(f::Function, mod::Symbol)

Execute `f` if the module named by `mod` is imported into `Main`.

The function `f` receives a constant of the given `mod` as argument to dispatch on for calling
functions in extensions.
"""
function if_module(f::Function, mod::Symbol)
    if mod in names(Main; imported = true)
        f(Val(mod))
    else
        throw(SerdeExtensionError(mod))
    end
end

"""
    to_symbol(m::Module)::Symbol

Convert a module name to a symbol.

Takes the `fullname` of the module, joins the individual components with a `_` and returns the
result as Symbol.
"""
function to_symbol(m::Module)::Symbol
    Symbol(join(string.(fullname(m)), '_'))
end

function to_string end
function to_string(ext::Module, args...; kwargs...)
    to_string(Val(to_symbol(ext)), args...; kwargs...)
end

function from_string end
function from_string(ext::Module, args...; kwargs...)
    from_string(Val(to_symbol(ext)), args...; kwargs...)
end

function parse end
function parse(ext::Module, args...; kwargs...)
    parse(Val(to_symbol(ext)), args...; kwargs...)
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
