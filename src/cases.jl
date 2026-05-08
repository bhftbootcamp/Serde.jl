
function to_camel_case(s::AbstractString)::String
    parts = split(s, '_')
    return parts[1] * join(titlecase(w) for w in parts[2:end])
end

function to_pascal_case(s::AbstractString)::String
    return join(titlecase(w) for w in split(s, '_'))
end

function to_kebab_case(s::AbstractString)::String
    return join(lowercase.(split(s, '_')), '-')
end

function to_snake_case(s::AbstractString)::String
    io = IOBuffer()
    for (i, c) in enumerate(s)
        isuppercase(c) && i > 1 && write(io, '_')
        write(io, lowercase(c))
    end
    return String(take!(io))
end

"""
    CamelCase

Serialization/deserialization context that renames all struct fields to `camelCase`.

Pass a `CamelCase()` instance as the first argument to any `from_*` or `to_*` function
to have all `snake_case` field names automatically converted to `camelCase` in the output
(serialization) and looked up as `camelCase` in the input (deserialization).

This is the most common convention in JSON APIs. Field-specific overrides via
[`Serde.ser_name`](@ref) or [`Serde.deser_name`](@ref) still take precedence over the
context when defined for a type.

# Examples
```julia
julia> struct Config
           database_host::String
           max_retries::Int
       end

julia> to_json(CamelCase(), Config("localhost", 3))
"{\"databaseHost\":\"localhost\",\"maxRetries\":3}"

julia> from_json(CamelCase(), Config, "{\"databaseHost\":\"localhost\",\"maxRetries\":3}")
Config("localhost", 3)
```

See also: [`PascalCase`](@ref), [`KebabCase`](@ref), [`LowerCase`](@ref).
"""
struct CamelCase end

"""
    PascalCase

Serialization/deserialization context that renames all struct fields to `PascalCase`.

All `snake_case` field names are converted to `PascalCase` (every word capitalized,
no separator) when serializing or deserializing with this context.

# Examples
```julia
julia> struct Event
           event_type::String
           user_id::Int
       end

julia> to_json(PascalCase(), Event("login", 42))
"{\"EventType\":\"login\",\"UserId\":42}"

julia> from_json(PascalCase(), Event, "{\"EventType\":\"login\",\"UserId\":42}")
Event("login", 42)
```

See also: [`CamelCase`](@ref), [`KebabCase`](@ref), [`LowerCase`](@ref).
"""
struct PascalCase end

"""
    KebabCase

Serialization/deserialization context that renames all struct fields to `kebab-case`.

All `snake_case` field names are converted to `kebab-case` (words joined with `-`,
all lowercase) when serializing or deserializing with this context.

# Examples
```julia
julia> struct Header
           content_type::String
           accept_encoding::String
       end

julia> to_json(KebabCase(), Header("application/json", "gzip"))
"{\"content-type\":\"application/json\",\"accept-encoding\":\"gzip\"}"
```

See also: [`CamelCase`](@ref), [`PascalCase`](@ref), [`LowerCase`](@ref).
"""
struct KebabCase end

"""
    LowerCase

Serialization/deserialization context that lowercases all struct field names.

All field names are converted to lowercase (no separator changes, only case folding)
when serializing or deserializing with this context.

# Examples
```julia
julia> struct Params
           Symbol_Name::String
           Count::Int
       end

julia> to_json(LowerCase(), Params("foo", 1))
"{\"symbol_name\":\"foo\",\"count\":1}"
```

See also: [`CamelCase`](@ref), [`PascalCase`](@ref), [`KebabCase`](@ref).
"""
struct LowerCase end

ser_name(::CamelCase,  ::Type{T}, ::Val{x}) where {T,x} = Symbol(to_camel_case(string(x)))
ser_name(::PascalCase, ::Type{T}, ::Val{x}) where {T,x} = Symbol(to_pascal_case(string(x)))
ser_name(::KebabCase,  ::Type{T}, ::Val{x}) where {T,x} = Symbol(to_kebab_case(string(x)))
ser_name(::LowerCase,  ::Type{T}, ::Val{x}) where {T,x} = Symbol(lowercase(string(x)))

deser_name(::CamelCase,  ::Type{T}, ::Val{x}) where {T,x} = Symbol(to_camel_case(string(x)))
deser_name(::PascalCase, ::Type{T}, ::Val{x}) where {T,x} = Symbol(to_pascal_case(string(x)))
deser_name(::KebabCase,  ::Type{T}, ::Val{x}) where {T,x} = Symbol(to_kebab_case(string(x)))
deser_name(::LowerCase,  ::Type{T}, ::Val{x}) where {T,x} = Symbol(lowercase(string(x)))
