module SerdeXml

export parse_xml, from_xml, try_from_xml, to_xml

import ..ParseError, ..SerdeError, ..DefaultStrategy

"""
    parse_xml(x::Union{AbstractString, Vector{UInt8}}; dict_type = Dict{String,Any}, force_array = false, kw...) -> Dict

Parse an XML string or byte vector into a nested `Dict` without mapping to a target type.

XML attributes and child elements are both represented as dict entries. Text content of
a node is stored under the special key `"_"`. When the same child element name appears
multiple times, the values are collected into a `Vector`.

# Arguments
- `x`: XML text as a `String` or `Vector{UInt8}`.

# Keyword arguments
- `dict_type::Type{<:AbstractDict}`: concrete dict type for nodes (default `Dict{String,Any}`).
- `force_array::Bool = false`: when `true`, all child elements are wrapped in `Vector`
  even if they appear only once.

# Returns
A nested dict representing the root XML element.

# Throws
- [`ParseError`](@ref): if `x` is malformed XML.

# Examples
```julia
julia> parse_xml("<root><x>1</x><y>2</y></root>")
Dict{String, Any}("x" => Dict{String, Any}("_" => "1"), "y" => Dict{String, Any}("_" => "2"))
```

See also: [`from_xml`](@ref).
"""
function parse_xml end

"""
    from_xml(::Type{T}, x; kw...) -> T
    from_xml(strategy, ::Type{T}, x; kw...) -> T
    from_xml(f::Function, x; kw...) -> Any

Parse an XML string and deserialize the root element into type `T`.

The XML is first parsed into a nested dict via [`parse_xml`](@ref), then deserialized
using [`Serde.deser`](@ref). XML attributes and child elements are accessible as dict
keys. Text content of the root element is available under the key `"_"`.

Pass a context object `strategy` (e.g. [`CamelCase()`](@ref)) to apply global field-renaming.

# Arguments
- `::Type{T}`: target type to construct.
- `x`: XML text as a `String` or `Vector{UInt8}`.
- `strategy`: optional context object.

# Returns
A value of type `T`.

# Throws
- [`ParseError`](@ref): if `x` is malformed XML.
- [`MissingFieldError`](@ref): if a required struct field is absent.
- [`TypeMismatchError`](@ref): if a value cannot be coerced to the field type.

# Examples
```julia
julia> struct Point; x::Int; y::Int; end

julia> from_xml(Point, "<root x=\"1\" y=\"2\"/>")
Point(1, 2)
```

See also: [`to_xml`](@ref), [`parse_xml`](@ref).
"""
function from_xml end

function try_from_xml end

"""
    to_xml(val; key::String = "xml") -> String
    to_xml(strategy, val; key::String = "xml") -> String

Serialize `val` into an XML string.

The value is wrapped in a root element named by `key`. Scalar (primitive) struct fields
are serialized as XML attributes of the wrapping element. Nested structs produce nested
child elements. `nothing` and `missing` fields are omitted. `Vector` fields produce
repeated sibling elements with the same tag name.

Pass a context object `strategy` (e.g. [`CamelCase()`](@ref)) to apply global field-renaming.

All serialization traits ([`Serde.ser_name`](@ref), [`Serde.ser_value`](@ref),
[`Serde.ser_skip`](@ref)) are applied.

# Arguments
- `val`: the value to serialize.
- `strategy`: optional context object.

# Keyword arguments
- `key::String = "xml"`: name of the root XML element.

# Returns
An XML-formatted `String`.

# Examples
```julia
julia> struct Point; x::Int; y::Int; end

julia> to_xml(Point(1, 2)) |> print
<xml x="1" y="2"/>

julia> to_xml(Point(1, 2); key="point") |> print
<point x="1" y="2"/>
```

See also: [`from_xml`](@ref).
"""
function to_xml end

const _XML_HINT = "XML support requires the `EzXML` package. " *
                  "Run `import Pkg; Pkg.add(\"EzXML\")` and then " *
                  "`import EzXML` to activate the extension."

parse_xml(args...; kw...)    = throw(ArgumentError(_XML_HINT))
from_xml(args...; kw...)     = throw(ArgumentError(_XML_HINT))
try_from_xml(args...; kw...) = throw(ArgumentError(_XML_HINT))
to_xml(args...; kw...)       = throw(ArgumentError(_XML_HINT))

end
