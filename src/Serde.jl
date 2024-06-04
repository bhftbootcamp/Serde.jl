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

"""
    to_string(ext::Module, ...; ...)

Serialize a Julia object to a string.

The first Argument (`ext`) is a Module that is used to dispatch the function call. This means you
can provide your own methods for arbitrary modules, if desired. The default functions provided with
`Serde` also use this function internally.

```julia
julia> using Serde

julia> import YAML

julia> @assert Serde.to_string(YAML, Dict("a" => 1)) == Serde.YAML.to_yaml(Dict("a" => 1))
```

# Implementation

The actual implementations don't dispatch on the module, but a `Symbol` generated from the `Module`
argument instead. The [`to_symbol`](@ref) function is used internally to generate the symbols. This
symbol is then wrapped into a `Val` type to enable dispatch on the symbols constant value.

If you have the module, determine the Symbol like this:

```julia
julia> import Serde

julia> import MyAwesomeModule

julia> Serde.to_symbol(MyAwesomeModule)
:MyAwesomeModule

julia> import MyAwesomeModule.MyMarkup

julia> Serde.to_symbol(MyMarkup)
:MyAwesomeModule_MyMarkup
```

Then implement your code as follows:

```julia
using Serde

function Serde.to_string(::Val{:MyAwesomeModule_MyMarkup}, args...; kwargs...)
    ret = ""
    # Do some module-specific processing here ...
    return ret
end
```

!!! warning "A hint on type piracy"
    Since dispatch takes place on symbols rather than real modules, it is possible to define the
    [`to_string`](@ref), [`from_string`](@ref) and [`parse`](@ref) methods for entirely foreign
    modules without even importing them. Please [avoid type piracy][1] and prefer to define your
    own module when adding methods to these functions.

    [1]: https://docs.julialang.org/en/v1/manual/style-guide/#Avoid-type-piracy

If you don't want to spell out the symbol yourself, you can also lean into Julias macros to have
the correct symbol filled in by the interpreter:

```julia
using Serde
import MyAwesomeModule.MyMarkup

@eval function Serde.to_string(::Val{Serde.to_symbol(MyMarkup)}, args...; kwargs...)
    ret = ""
    # Do some module-specific processing here ...
    return ret
end
```
"""
function to_string end
function to_string(ext::Module, args...; kwargs...)
    to_string(Val(to_symbol(ext)), args...; kwargs...)
end

"""
    from_string(ext::Module, ...; ...)

Deserialize a string to a Julia object.

The first Argument (`ext`) is a Module that is used to dispatch the function call. This means you
can provide your own methods for arbitrary modules, if desired. The default functions provided with
`Serde` also use this function internally.

!!! info "Overloading/Adding your own Implementation"
    To add your own method overloads, refer to the *Implementation* section in [`to_string`](@ref).

```julia
julia> using Serde

julia> import YAML

julia> val = "a: 1\n"

julia> @assert Serde.from_string(YAML, Dict, val) == Serde.YAML.deser_yaml(Dict, val)
```
"""
function from_string end
function from_string(ext::Module, args...; kwargs...)
    from_string(Val(to_symbol(ext)), args...; kwargs...)
end

"""
    parse(ext::Module, ...; ...)

Parse a string into a Julia `Dict`.

The first Argument (`ext`) is a Module that is used to dispatch the function call. This means you
can provide your own methods for arbitrary modules, if desired. The default functions provided with
`Serde` also use this function internally.

!!! info "Overloading/Adding your own Implementation"
    To add your own method overloads, refer to the *Implementation* section in [`to_string`](@ref).

```julia
julia> using Serde

julia> import YAML

julia> val = "a: 1\n"

julia> @assert Serde.parse(YAML, val) == Serde.YAML.parse_yaml(val)
```
"""
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
