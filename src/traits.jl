"""
    Serde.deser_name(::Type{T}, ::Val{field}) -> Symbol
    Serde.deser_name(strategy, ::Type{T}, ::Val{field}) -> Symbol

Returns the key name to look up in the input data when deserializing `field` of type `T`.

Override this method to create field name aliases — for example, to accept `camelCase` JSON
keys into `snake_case` Julia struct fields. The default implementation returns `field` unchanged.

The context-aware variant is called when a context object is passed to `from_json` / `from_yaml`
/ etc. Case-renaming contexts such as [`CamelCase`](@ref) override this method.

# Arguments
- `::Type{T}`: the struct type being deserialized.
- `::Val{field}`: the Julia field name as a `Val`.

# Returns
The `Symbol` (or `String`) key to look up in the parsed data.

# Examples
```julia
struct User
    user_name::String
    created_at::String
end

# Accept "userName" in JSON but store as user_name
Serde.deser_name(::Type{User}, ::Val{:user_name}) = :userName
Serde.deser_name(::Type{User}, ::Val{:created_at}) = :createdAt
```

See also: [`Serde.ser_name`](@ref), [`CamelCase`](@ref), [`PascalCase`](@ref).
"""
deser_name(::Type{T}, ::Val{x}) where {T,x} = x

"""
    Serde.has_default(::Type{T}, ::Val{field}) -> Bool
    Serde.has_default(strategy, ::Type{T}, ::Val{field}) -> Bool

Returns `true` if `field` of type `T` has a registered default value.

This predicate separates "the default is `nothing`" from "no default exists at all".
When `has_default` returns `false` and the field is absent from the input,
deserialization throws [`MissingFieldError`](@ref) (unless the field type is nullable).

Override both `has_default` and [`Serde.deser_default`](@ref) together:

```julia
struct Config
    host::String
    port::Int
    timeout::Int
end

Serde.has_default(::Type{Config}, ::Val{:timeout}) = true
Serde.deser_default(::Type{Config}, ::Val{:timeout}) = 30
```

See also: [`Serde.deser_default`](@ref), [`MissingFieldError`](@ref).
"""
has_default(::Type{T}, ::Val{x}) where {T,x} = false

"""
    Serde.deser_default(::Type{T}, ::Val{field})
    Serde.deser_default(strategy, ::Type{T}, ::Val{field})

Returns the default value for `field` of type `T` when the field is absent from the input.

Only called when [`Serde.has_default`](@ref)`(T, Val(field))` returns `true`. The return value
must be assignable to the field's declared type.

# Examples
```julia
struct Server
    host::String
    port::Int
end

Serde.has_default(::Type{Server}, ::Val{:port}) = true
Serde.deser_default(::Type{Server}, ::Val{:port}) = 8080
```

See also: [`Serde.has_default`](@ref).
"""
deser_default(::Type{T}, ::Val{x}) where {T,x} = nothing

"""
    Serde.nulltype(::Type{T})

Returns the sentinel value to use when a field of type `T` is null or empty in the input.

The built-in specializations are:
- `nulltype(Nothing)` → `nothing`
- `nulltype(Missing)` → `missing`
- `nulltype(Union{Nothing,T})` → `nothing`
- `nulltype(Union{Missing,T})` → `missing`

For all other types the default returns `nothing`, but this can be overridden.

See also: [`Serde.isempty_value`](@ref).
"""
nulltype(::Type{T}) where {T}                  = nothing
nulltype(::Type{Missing})                      = missing
nulltype(::Type{Union{Nothing,T}}) where {T}   = nothing
nulltype(::Type{Union{Missing,T}}) where {T}   = missing

"""
    Serde.isempty_value(::Type{T}, ::Val{field}, value) -> Bool
    Serde.isempty_value(strategy, ::Type{T}, ::Val{field}, value) -> Bool

Returns `true` if `value` should be treated as logically empty and replaced with
[`Serde.nulltype`](@ref)`(FieldType)` during deserialization.

The default implementation always returns `false`. Override to treat domain-specific
sentinel values (e.g. empty strings, zero, `"N/A"`) as null:

# Examples
```julia
struct Trade
    price::Union{Nothing,Float64}
    volume::Union{Nothing,Float64}
end

# Treat 0.0 as missing price
Serde.isempty_value(::Type{Trade}, ::Val{:price}, v::Float64) = v == 0.0
```

See also: [`Serde.nulltype`](@ref).
"""
isempty_value(::Type{T}, ::Val{x}, value) where {T,x} = false

"""
    Serde.deser_transform(::Type{T}, ::Type{FieldType}, value)
    Serde.deser_transform(strategy, ::Type{T}, ::Type{FieldType}, value)

Transforms `value` before it is stored into a field of `FieldType` during deserialization
of type `T`. Called after null-checking but before type conversion.

Use this hook for lightweight value normalization (e.g. trimming strings, unit conversion)
that applies uniformly across all sources.

# Examples
```julia
struct Measurement
    value_cm::Float64
end

# Input is in millimetres; convert to centimetres
Serde.deser_transform(::Type{Measurement}, ::Type{Float64}, v::Number) = v / 10.0
```

See also: [`Serde.deser_validate`](@ref).
"""
deser_transform(::Type{T}, ::Type{F}, value) where {T,F} = value

"""
    Serde.deser_validate(::Type{T}, ::Val{field}, value) -> nothing
    Serde.deser_validate(strategy, ::Type{T}, ::Val{field}, value) -> nothing

Validates `value` for `field` of type `T` after deserialization and type conversion.
The method should return `nothing` on success and throw a [`ValidationError`](@ref)
(or any other exception) on failure.

# Examples
```julia
struct Order
    quantity::Int
    price::Float64
end

function Serde.deser_validate(::Type{Order}, ::Val{:quantity}, v::Int)
    v > 0 || throw(ValidationError(Order, :quantity, v, "quantity must be positive"))
end

function Serde.deser_validate(::Type{Order}, ::Val{:price}, v::Float64)
    v > 0 || throw(ValidationError(Order, :price, v, "price must be positive"))
end
```

See also: [`ValidationError`](@ref), [`Serde.deser_transform`](@ref).
"""
deser_validate(::Type{T}, ::Val{x}, value) where {T,x} = nothing

# ── Context-aware fallbacks ──
# strategy is the first positional argument; falls back to the no-context version.

@inline deser_name(strategy, ::Type{T}, ::Val{x}) where {T,x} = deser_name(T, Val(x))
@inline has_default(strategy, ::Type{T}, ::Val{x}) where {T,x} = has_default(T, Val(x))
@inline deser_default(strategy, ::Type{T}, ::Val{x}) where {T,x} = deser_default(T, Val(x))
@inline isempty_value(strategy, ::Type{T}, ::Val{x}, v) where {T,x} = isempty_value(T, Val(x), v)
@inline deser_transform(strategy, ::Type{T}, ::Type{F}, v) where {T,F} = deser_transform(T, F, v)
@inline deser_validate(strategy, ::Type{T}, ::Val{x}, v) where {T,x} = deser_validate(T, Val(x), v)

"""
    Serde.ser_name(::Type{T}, ::Val{field}) -> Symbol
    Serde.ser_name(strategy, ::Type{T}, ::Val{field}) -> Symbol

Returns the output key name for `field` of type `T` during serialization.

Override to rename individual fields in the serialized output. The default returns `field`
unchanged. Context objects such as [`CamelCase`](@ref) provide global renaming policies
by overriding the context-aware variant.

# Examples
```julia
struct User
    user_name::String
end

# Output as "userName" in JSON/YAML/etc.
Serde.ser_name(::Type{User}, ::Val{:user_name}) = :userName
```

See also: [`Serde.deser_name`](@ref), [`CamelCase`](@ref).
"""
ser_name(::Type{T}, ::Val{x}) where {T,x} = x

"""
    Serde.ser_value(::Type{T}, ::Val{field}, value)
    Serde.ser_value(strategy, ::Type{T}, ::Val{field}, value)

Transforms the value of `field` in a value of type `T` before serialization.

Applied per-field, before [`Serde.ser_type`](@ref). Use this hook to convert domain values
to serialization-friendly forms (e.g. `DateTime` to Unix timestamp, `Enum` to string code).

# Examples
```julia
struct Event
    timestamp::Int64  # stored as Unix ms
end

# Store the underlying DateTime as milliseconds since epoch
Serde.ser_value(::Type{Event}, ::Val{:timestamp}, v::DateTime) =
    Dates.value(v - DateTime(1970))
```

See also: [`Serde.ser_type`](@ref), [`Serde.ser_skip`](@ref).
"""
ser_value(::Type{T}, ::Val{x}, v) where {T,x} = v

"""
    Serde.ser_type(::Type{T}, value)
    Serde.ser_type(strategy, ::Type{T}, value)

Type-level value transformation applied during serialization after [`Serde.ser_value`](@ref).

Unlike `ser_value`, this hook is not per-field: it is dispatched on the type `T` being
serialized and the resulting value. Use it for uniform post-processing (e.g. rounding
all floats in a struct).

See also: [`Serde.ser_value`](@ref).
"""
ser_type(::Type{T}, v) where {T} = v

"""
    Serde.ser_skip(::Type{T}, ::Val{field}) -> Bool
    Serde.ser_skip(strategy, ::Type{T}, ::Val{field}) -> Bool

Returns `true` to unconditionally omit `field` of type `T` from serialized output.

Use to exclude internal or sensitive fields regardless of their value. The default
returns `false` (include all fields).

# Examples
```julia
struct User
    name::String
    password_hash::String  # never serialize this
end

Serde.ser_skip(::Type{User}, ::Val{:password_hash}) = true
```

See also: [`Serde.ser_skip(::Type, ::Val, ::Any)`](@ref).
"""
ser_skip(::Type{T}, ::Val{x}) where {T,x} = false

"""
    Serde.ser_skip(::Type{T}, ::Val{field}, value) -> Bool
    Serde.ser_skip(strategy, ::Type{T}, ::Val{field}, value) -> Bool

Returns `true` to omit `field` of type `T` when it holds the given `value`.

Use to implement "skip if null", "skip if zero", or any value-conditional omission.
Falls back to `ser_skip(T, Val(field))` (the value-independent variant) by default.

# Examples
```julia
struct Response
    data::Union{Nothing,String}
    error::Union{Nothing,String}
end

# Omit fields that are nothing
Serde.ser_skip(::Type{Response}, ::Val{:data}, v) = isnothing(v)
Serde.ser_skip(::Type{Response}, ::Val{:error}, v) = isnothing(v)
```

See also: [`Serde.ser_skip(::Type, ::Val)`](@ref), [`Serde.isnull`](@ref).
"""
ser_skip(::Type{T}, ::Val{x}, v) where {T,x} = ser_skip(T, Val(x))

# ── Context-aware fallbacks ──

@inline ser_name(strategy, ::Type{T}, ::Val{x}) where {T,x} = ser_name(T, Val(x))
@inline ser_value(strategy, ::Type{T}, ::Val{x}, v) where {T,x} = ser_value(T, Val(x), v)
@inline ser_type(strategy, ::Type{T}, v) where {T} = ser_type(T, v)
@inline ser_skip(strategy, ::Type{T}, ::Val{x}) where {T,x} = ser_skip(T, Val(x))
@inline ser_skip(strategy, ::Type{T}, ::Val{x}, v) where {T,x} = ser_skip(strategy, T, Val(x))

"""
    Serde.tag_key(::Type{T}) -> Union{Nothing, Symbol, String}

Returns the name of the discriminator field for tagged-union type `T`.

When `ClassType(T)` is `TaggedClass()`, the deserializer reads this field from the
input to decide which concrete subtype to construct.  Return `nothing` (default)
to indicate that `T` is not a tagged union.

# Examples
```julia
abstract type Message end
Serde.ClassType(::Type{<:Message}) = Serde.TaggedClass()
Serde.tag_key(::Type{<:Message}) = "type"
```

See also: [`Serde.tag_subtypes`](@ref), [`register_tagged_subtype`](@ref).
"""
tag_key(::Type{T}) where {T} = nothing

"""
    Serde.tag_subtypes(::Type{T}) -> Tuple

Returns a tuple of `(tag_value => SubType, ...)` pairs for the tagged union type `T`.

The deserializer matches the value of the tag field (returned by [`Serde.tag_key`](@ref))
against the tag values in this tuple and then deserializes the full object as the
corresponding subtype.

Prefer [`register_tagged_subtype`](@ref) to adding entries here manually, as it handles
dynamic registration without requiring a module re-evaluation.

See also: [`Serde.tag_key`](@ref), [`register_tagged_subtype`](@ref).
"""
tag_subtypes(::Type{T}) where {T} = ()

"""
    register_tagged_subtype(parent::Type, tag_val::String, subtype::Type)

Register `subtype` as a concrete variant of the tagged-union abstract type `parent`,
identified by the discriminator value `tag_val`.

The `parent` type must have `Serde.ClassType(::Type{<:parent}) = Serde.TaggedClass()`
and `Serde.tag_key(::Type{<:parent})` defined before calling this function.

# Arguments
- `parent::Type`: the abstract tagged-union type.
- `tag_val::String`: the discriminator string that selects `subtype`.
- `subtype::Type`: the concrete struct type to construct when `tag_val` is found.

# Examples
```julia
abstract type Event end
Serde.ClassType(::Type{<:Event}) = Serde.TaggedClass()
Serde.tag_key(::Type{<:Event}) = "kind"

struct LoginEvent <: Event
    user_id::Int
end

struct LogoutEvent <: Event
    user_id::Int
    session_ms::Int
end

register_tagged_subtype(Event, "login",  LoginEvent)
register_tagged_subtype(Event, "logout", LogoutEvent)

# Now from_json dispatches on "kind":
json = \"\"\"{"kind":"login","user_id":42}\"\"\"
from_json(Event, json)  # → LoginEvent(42)
```

See also: [`Serde.tag_key`](@ref), [`Serde.tag_subtypes`](@ref), [`TaggedClass`](@ref).
"""
function register_tagged_subtype(parent::Type, tag_val::String, subtype::Type)
    existing = Pair{String,Type}[p for p in tag_subtypes(parent)]
    push!(existing, tag_val => subtype)
    new_subtypes = Tuple(existing)
    @eval tag_subtypes(::Type{T}) where {T<:$parent} = $new_subtypes
end
