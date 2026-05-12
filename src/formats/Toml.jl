module SerdeToml

export parse_toml, from_toml, try_from_toml, to_toml

import ..ParseError, ..SerdeError, ..DefaultStrategy

"""
    parse_toml(x::Union{AbstractString, Vector{UInt8}}; kw...) -> Dict{String, Any}

Parse a TOML string or byte vector into a `Dict{String,Any}` without mapping to a target type.

Delegates to the standard library `TOML.parse`.

# Arguments
- `x`: TOML text as a `String` or `Vector{UInt8}`.

# Returns
A `Dict{String, Any}` representing the top-level TOML document.

# Throws
- [`ParseError`](@ref): if `x` contains malformed TOML.

# Examples
```julia
julia> parse_toml("host = \\"localhost\\"\\nport = 8080")
Dict{String, Any}("host" => "localhost", "port" => 8080)
```

See also: [`from_toml`](@ref), [`try_from_toml`](@ref).
"""
function parse_toml end

"""
    from_toml(::Type{T}, x; kw...) -> T
    from_toml(strategy, ::Type{T}, x; kw...) -> T
    from_toml(f::Function, x; kw...) -> Any

Parse a TOML string and deserialize it into type `T`.

# Arguments
- `::Type{T}`: target type to construct.
- `x`: TOML text as a `String` or `Vector{UInt8}`.
- `strategy`: optional context object (e.g. [`CamelCase()`](@ref)).
- `f::Function`: function `(parsed_data) -> Type` for dynamic type dispatch.

# Returns
A value of type `T`.

# Throws
- [`ParseError`](@ref): if `x` is malformed TOML.
- [`MissingFieldError`](@ref): if a required struct field is absent.
- [`TypeMismatchError`](@ref): if a value cannot be coerced to the field type.

# Examples
```julia
julia> struct Server; host::String; port::Int; end

julia> from_toml(Server, "host = \\"localhost\\"\\nport = 9000")
Server("localhost", 9000)
```

See also: [`try_from_toml`](@ref), [`to_toml`](@ref), [`parse_toml`](@ref).
"""
function from_toml end

"""
    try_from_toml(::Type{T}, x; kw...) -> Union{T, SerdeError}
    try_from_toml(strategy, ::Type{T}, x; kw...) -> Union{T, SerdeError}

Like [`from_toml`](@ref) but returns a [`SerdeError`](@ref) instead of throwing on failure.

# Returns
- `T` on success.
- A [`ParseError`](@ref) or [`DeserError`](@ref) subtype on failure.

See also: [`from_toml`](@ref), [`SerdeError`](@ref).
"""
function try_from_toml end

"""
    to_toml(data; kw...) -> String
    to_toml(strategy, data; kw...) -> String

Serialize `data` into a TOML string.

Struct fields, dicts, and arrays are mapped to TOML sections, tables, and arrays of tables
following TOML conventions. Scalar fields are written as inline key-value pairs; nested
structs produce `[section]` headers.

Pass a context object `strategy` (e.g. [`CamelCase()`](@ref)) as the first argument to apply
global field-renaming.

All serialization traits ([`Serde.ser_name`](@ref), [`Serde.ser_value`](@ref),
[`Serde.ser_skip`](@ref)) are applied. Null values (`nothing`, `missing`) are omitted.

# Arguments
- `data`: value to serialize (struct or dict).
- `strategy`: optional context object.

# Returns
A TOML-formatted `String`.

# Examples
```julia
julia> struct Server; host::String; port::Int; end

julia> to_toml(Server("localhost", 8080)) |> print
host = "localhost"
port = 8080
```

See also: [`from_toml`](@ref).
"""
function to_toml end

const _TOML_HINT = "TOML support requires the `TOML` stdlib package. " *
                   "Run `import TOML` to activate the extension."

parse_toml(args...; kw...)    = throw(ArgumentError(_TOML_HINT))
from_toml(args...; kw...)     = throw(ArgumentError(_TOML_HINT))
try_from_toml(args...; kw...) = throw(ArgumentError(_TOML_HINT))
to_toml(args...; kw...)       = throw(ArgumentError(_TOML_HINT))

end
