using Dates
using UUIDs

"""
    ClassType

Abstract type that classifies Julia types for the Serde serialization/deserialization engine.

The engine dispatches on `ClassType(T)` to select the construction strategy for a given type.
Every Julia type maps to exactly one concrete subtype of `ClassType`.

Concrete subtypes:

| Subtype          | Matched Julia types                                        |
|:-----------------|:-----------------------------------------------------------|
| `StructClass`    | Any user-defined `struct` (default fallback)               |
| `TaggedClass`    | Abstract types registered with [`register_tagged_subtype`](@ref) |
| `PrimitiveClass` | `String`, `Number`, `Symbol`, `Char`, `Enum`, `DateTime`, `UUID` |
| `NullClass`      | `Nothing`, `Missing`                                       |
| `VectorClass`    | `AbstractArray`, `Tuple`, `AbstractSet`                    |
| `DictClass`      | `AbstractDict`, `Pair`                                     |
| `NTupleClass`    | `NamedTuple`                                               |
| `UnionClass`     | `Union{Nothing,T}`, `Union{Missing,T}`                     |

To make an abstract type act as a tagged union, override `ClassType` for it:

```julia
abstract type Shape end
Serde.ClassType(::Type{<:Shape}) = Serde.TaggedClass()
```

See also: [`register_tagged_subtype`](@ref), [`StructClass`](@ref), [`TaggedClass`](@ref).
"""
abstract type ClassType end

"""
    StructClass <: ClassType

Indicates that a type should be deserialized field-by-field from a dict or positionally
from a vector. This is the default for any user-defined `struct`.
"""
struct StructClass   <: ClassType end

"""
    TaggedClass <: ClassType

Indicates that an abstract type uses a discriminator field (tag) to select the concrete
subtype during deserialization. Register subtypes with [`register_tagged_subtype`](@ref).

See also: [`Serde.tag_key`](@ref), [`Serde.tag_subtypes`](@ref).
"""
struct TaggedClass   <: ClassType end

"""
    PrimitiveClass <: ClassType

Indicates that a type is a scalar value (string, number, symbol, enum, date, UUID).
The engine converts the raw parsed value directly to the target type.
"""
struct PrimitiveClass <: ClassType end

"""
    NullClass <: ClassType

Indicates that a type represents the absence of a value (`Nothing` or `Missing`).
"""
struct NullClass      <: ClassType end

"""
    VectorClass <: ClassType

Indicates that a type is a sequential collection (`AbstractArray`, `Tuple`, `AbstractSet`).
"""
struct VectorClass    <: ClassType end

"""
    DictClass <: ClassType

Indicates that a type is a key-value mapping (`AbstractDict`, `Pair`).
"""
struct DictClass      <: ClassType end

"""
    NTupleClass <: ClassType

Indicates that a type is a `NamedTuple`.
"""
struct NTupleClass    <: ClassType end

"""
    UnionClass <: ClassType

Indicates that a type is a nullable union (`Union{Nothing,T}` or `Union{Missing,T}`).
The engine unwraps the union and deserializes the inner type `T`.
"""
struct UnionClass     <: ClassType end

ClassType(::T) where {T} = ClassType(T)

ClassType(::Type{<:Any})            = StructClass()
ClassType(::Type{<:AbstractString}) = PrimitiveClass()
ClassType(::Type{<:AbstractChar})   = PrimitiveClass()
ClassType(::Type{<:Number})         = PrimitiveClass()
ClassType(::Type{<:Enum})           = PrimitiveClass()
ClassType(::Type{<:Symbol})         = PrimitiveClass()
ClassType(::Type{<:Dates.TimeType}) = PrimitiveClass()
ClassType(::Type{UUID})             = PrimitiveClass()

ClassType(::Type{Nothing}) = NullClass()
ClassType(::Type{Missing}) = NullClass()

ClassType(::Type{<:AbstractArray}) = VectorClass()
ClassType(::Type{<:AbstractSet})   = VectorClass()
ClassType(::Type{<:Tuple})         = VectorClass()

ClassType(::Type{<:AbstractDict}) = DictClass()
ClassType(::Type{<:Pair})         = DictClass()

ClassType(::Type{<:NamedTuple}) = NTupleClass()

ClassType(::Type{<:Function}) = throw(ArgumentError("Functions are not serializable"))

function ClassType(::Type{Union{Nothing,T}}) where {T}
    return UnionClass()
end

function ClassType(::Type{Union{Missing,T}}) where {T}
    return UnionClass()
end

"""
    SerdeError <: Exception

Abstract base type for all errors thrown by Serde. There are two branches:

- [`ParseError`](@ref) — the raw input is malformed (unparseable format bytes/text).
- [`DeserError`](@ref) — the data parsed successfully but cannot be mapped to the target type.

Catch `SerdeError` to handle both categories uniformly:

```julia
result = try
    from_json(MyType, json_string)
catch e
    e isa SerdeError ? handle_error(e) : rethrow()
end
```

See also: [`ParseError`](@ref), [`DeserError`](@ref), [`MissingFieldError`](@ref),
[`TypeMismatchError`](@ref), [`ValidationError`](@ref).
"""
abstract type SerdeError <: Exception end

"""
    ParseError <: SerdeError

Thrown when the raw input cannot be parsed as the expected format (malformed JSON, YAML, etc.).

# Fields
- `format::String`: the format name (`"JSON"`, `"YAML"`, `"TOML"`, `"CSV"`, `"XML"`, `"Query"`, `"MsgPack"`, `"BSON"`).
- `message::String`: human-readable description of the failure.
- `cause::Exception`: the underlying exception from the format parser.

# Examples
```julia
julia> try
           from_json(Int, "not json")
       catch e
           e isa ParseError && println(e.format, ": ", e.message)
       end
JSON: invalid JSON syntax
```

See also: [`SerdeError`](@ref), [`DeserError`](@ref).
"""
struct ParseError <: SerdeError
    format::String
    message::String
    cause::Exception
end

function Base.showerror(io::IO, e::ParseError)
    print(io, "ParseError (", e.format, "): ", e.message)
    print(io, "\n  caused by: ")
    showerror(io, e.cause)
end

"""
    DeserError <: SerdeError

Abstract base for all field-level deserialization errors. Catch `DeserError` to handle
any structural mismatch between the parsed data and the target type.

Concrete subtypes:
- [`MissingFieldError`](@ref) — a required field is absent.
- [`TypeMismatchError`](@ref) — a field value has an incompatible type.
- [`ValidationError`](@ref) — a field value fails a custom validation check.

See also: [`SerdeError`](@ref).
"""
abstract type DeserError <: SerdeError end

"""
    MissingFieldError <: DeserError

Thrown when a required field is absent from the input during deserialization.
A field is required unless [`Serde.has_default`](@ref) returns `true` for it or its
type is nullable (`Union{Nothing,T}`, `Union{Missing,T}`).

# Fields
- `type::Type`: the target struct type being constructed.
- `field::Symbol`: the name of the missing field.

# Examples
```julia
julia> struct Config
           host::String
           port::Int
       end

julia> try
           from_json(Config, "{\"host\":\"localhost\"}")
       catch e
           println(e)
       end
MissingFieldError: type 'Config' requires field 'port'
```

See also: [`Serde.has_default`](@ref), [`Serde.deser_default`](@ref).
"""
struct MissingFieldError <: DeserError
    type::Type
    field::Symbol
end

function Base.showerror(io::IO, e::MissingFieldError)
    print(io, "MissingFieldError: type '", e.type, "' requires field '", e.field, "'")
end

"""
    TypeMismatchError <: DeserError

Thrown when the value found in the input cannot be converted to the expected field type.

# Fields
- `type::Type`: the struct type being constructed.
- `field::Symbol`: the field where the mismatch occurred.
- `expected::Type`: the Julia type declared for this field.
- `got::Type`: the actual type of the value found in the input.
- `value::Any`: the offending value.

# Examples
```julia
julia> struct Cfg; port::Int; end

julia> try
           from_json(Cfg, "{\"port\":\"not_a_number\"}")
       catch e
           e isa TypeMismatchError && println("field: ", e.field)
       end
field: port
```

See also: [`DeserError`](@ref).
"""
struct TypeMismatchError <: DeserError
    type::Type
    field::Symbol
    expected::Type
    got::Type
    value::Any
end

function Base.showerror(io::IO, e::TypeMismatchError)
    print(io, "TypeMismatchError: field '", e.field, "' of ", e.type)
    print(io, " — expected ", e.expected, ", got ", e.got, " (", repr(e.value), ")")
end

"""
    ValidationError <: DeserError

Thrown when a deserialized field value fails a custom validation rule defined via
[`Serde.deser_validate`](@ref).

# Fields
- `type::Type`: the target struct type.
- `field::Symbol`: the field that failed validation.
- `value::Any`: the value that was rejected.
- `message::String`: human-readable description of the failure.

# Examples
```julia
julia> struct Age
           value::Int
       end

julia> function Serde.deser_validate(::Type{Age}, ::Val{:value}, v::Int)
           v >= 0 || throw(ValidationError(Age, :value, v, "age must be non-negative"))
       end

julia> try
           Serde.deser(Age, Dict("value" => -1))
       catch e
           println(e)
       end
ValidationError: field 'value' of Age (value: -1): age must be non-negative
```

See also: [`Serde.deser_validate`](@ref), [`DeserError`](@ref).
"""
struct ValidationError <: DeserError
    type::Type
    field::Symbol
    value::Any
    message::String
end

function Base.showerror(io::IO, e::ValidationError)
    print(io, "ValidationError: field '", e.field, "' of ", e.type)
    print(io, " (value: ", repr(e.value), "): ", e.message)
end
