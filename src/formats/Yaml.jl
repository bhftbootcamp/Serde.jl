module SerdeYaml

export parse_yaml, from_yaml, try_from_yaml, to_yaml

import ..ParseError, ..SerdeError, ..DefaultStrategy

"""
    parse_yaml(x::Union{AbstractString, Vector{UInt8}}; dict_type = Dict{String,Any}, kw...) -> Any

Parse a YAML string or byte vector into Julia data structures without mapping to a target type.

Returns the raw parsed value: a `Dict{String,Any}` for YAML mappings, a `Vector{Any}` for
sequences, or a scalar for plain values. Delegates to the `YAML.jl` library internally.

# Arguments
- `x`: YAML text as a `String` or `Vector{UInt8}`.

# Keyword arguments
- `dict_type::Type{<:AbstractDict}`: concrete dict type for YAML mappings (default `Dict{String,Any}`).
- Additional keyword arguments are forwarded to `YAML.load`.

# Returns
The parsed Julia value.

# Throws
- [`ParseError`](@ref): if `x` contains malformed YAML.

# Examples
```julia
julia> parse_yaml("x: 1\\ny: 2")
Dict{String, Any}("x" => 1, "y" => 2)
```

See also: [`from_yaml`](@ref), [`try_from_yaml`](@ref).
"""
function parse_yaml end

"""
    from_yaml(::Type{T}, x; kw...) -> T
    from_yaml(strategy, ::Type{T}, x; kw...) -> T
    from_yaml(f::Function, x; kw...) -> Any

Parse a YAML string and deserialize it into type `T`.

When called with a function `f`, the raw parsed value is passed to `f` to determine the
target type dynamically: `to_deser(f(parsed), parsed)`.

Pass a context object `strategy` (e.g. [`CamelCase()`](@ref)) as the first argument to apply
global field-renaming during deserialization.

# Arguments
- `::Type{T}`: target type to construct.
- `x`: YAML text as a `String` or `Vector{UInt8}`.
- `strategy`: optional context object.

# Returns
A value of type `T`.

# Throws
- [`ParseError`](@ref): if `x` is malformed YAML.
- [`MissingFieldError`](@ref): if a required struct field is absent.
- [`TypeMismatchError`](@ref): if a value cannot be coerced to the field type.

# Examples
```julia
julia> struct Point; x::Int; y::Int; end

julia> from_yaml(Point, "x: 1\\ny: 2")
Point(1, 2)
```

See also: [`try_from_yaml`](@ref), [`to_yaml`](@ref), [`parse_yaml`](@ref).
"""
function from_yaml end

"""
    try_from_yaml(::Type{T}, x; kw...) -> Union{T, SerdeError}
    try_from_yaml(strategy, ::Type{T}, x; kw...) -> Union{T, SerdeError}

Like [`from_yaml`](@ref) but returns a [`SerdeError`](@ref) instead of throwing on failure.

# Returns
- `T` on success.
- A [`ParseError`](@ref) or [`DeserError`](@ref) subtype on failure.

# Examples
```julia
julia> struct Point; x::Int; y::Int; end

julia> try_from_yaml(Point, "x: 1\\ny: 2")
Point(1, 2)

julia> try_from_yaml(Point, ": invalid yaml :") isa SerdeError
true
```

See also: [`from_yaml`](@ref), [`SerdeError`](@ref).
"""
function try_from_yaml end

"""
    to_yaml(data) -> String
    to_yaml(strategy, data) -> String

Serialize `data` into a YAML string.

All serialization traits ([`Serde.ser_name`](@ref), [`Serde.ser_value`](@ref),
[`Serde.ser_type`](@ref), [`Serde.ser_skip`](@ref)) are applied.

Pass a context object `strategy` (e.g. [`CamelCase()`](@ref)) as the first argument to apply
global field-renaming.

# Arguments
- `data`: the value to serialize.
- `strategy`: optional context object.

# Returns
A YAML `String`.

# Examples
```julia
julia> struct Server; host::String; port::Int; end

julia> to_yaml(CamelCase(), Server("localhost", 8080)) |> print
host: "localhost"
port: 8080
```

See also: [`from_yaml`](@ref).
"""
function to_yaml end

end
