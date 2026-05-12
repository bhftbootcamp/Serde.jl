module SerdeCsv

export parse_csv, from_csv, try_from_csv, to_csv

import ..ParseError, ..SerdeError, ..DefaultStrategy

"""
    parse_csv(x::Union{AbstractString, Vector{UInt8}}; delimiter = ",", kw...) -> Vector{NamedTuple}

Parse a CSV string or byte vector into a vector of `NamedTuple`s without mapping to a target type.

All values are returned as `String`; conversion to numeric types is performed later by
[`from_csv`](@ref) / [`Serde.deser`](@ref).

# Arguments
- `x`: CSV text as a `String` or `Vector{UInt8}`.

# Keyword arguments
- `delimiter::AbstractString = ","`: field separator.
- Additional keyword arguments are forwarded to `CSV.File`.

# Returns
A `Vector` of `NamedTuple`s (one per data row), with keys from the header row.

# Throws
- [`ParseError`](@ref): if `x` is not valid CSV.

# Examples
```julia
julia> parse_csv("name,age\\nAlice,30\\nBob,25")
2-element Vector{NamedTuple}:
 (name = "Alice", age = "30")
 (name = "Bob",   age = "25")
```

See also: [`from_csv`](@ref), [`try_from_csv`](@ref).
"""
function parse_csv end

"""
    from_csv(::Type{T}, x; kw...) -> Vector{T}
    from_csv(strategy, ::Type{T}, x; kw...) -> Vector{T}
    from_csv(f::Function, x; kw...) -> Any

Parse a CSV string and deserialize each row into type `T`, returning a `Vector{T}`.

Each CSV row is deserialized independently using the column headers as field names.
All values start as strings; the deserialization engine applies type coercion for each field.

Pass a context object `strategy` (e.g. [`CamelCase()`](@ref)) to apply global field-renaming.

# Arguments
- `::Type{T}`: target struct type per row.
- `x`: CSV text as `String` or `Vector{UInt8}`.
- `strategy`: optional context object.

# Keyword arguments
- `delimiter::AbstractString = ","`: field separator forwarded to `parse_csv`.

# Returns
`Vector{T}` — one element per data row.

# Throws
- [`ParseError`](@ref): if `x` is malformed CSV.
- [`MissingFieldError`](@ref): if a required struct field is absent.
- [`TypeMismatchError`](@ref): if a column value cannot be coerced to the field type.

# Examples
```julia
julia> struct Person; name::String; age::Int; end

julia> from_csv(Person, "name,age\\nAlice,30\\nBob,25")
2-element Vector{Person}:
 Person("Alice", 30)
 Person("Bob", 25)
```

See also: [`try_from_csv`](@ref), [`to_csv`](@ref), [`parse_csv`](@ref).
"""
function from_csv end

"""
    try_from_csv(::Type{T}, x; kw...) -> Union{Vector{T}, SerdeError}
    try_from_csv(strategy, ::Type{T}, x; kw...) -> Union{Vector{T}, SerdeError}

Like [`from_csv`](@ref) but returns a [`SerdeError`](@ref) instead of throwing on failure.

# Returns
- `Vector{T}` on success.
- A [`ParseError`](@ref) or [`DeserError`](@ref) subtype on failure.

See also: [`from_csv`](@ref), [`SerdeError`](@ref).
"""
function try_from_csv end

"""
    to_csv(data::Vector{T}; delimiter = ",", headers = String[], with_names = true) -> String
    to_csv(strategy, data::Vector{T}; delimiter = ",", headers = String[], with_names = true) -> String

Serialize a vector of structs into a CSV string.

The column headers are derived from the struct field names via [`Serde.ser_name`](@ref).
Nested structs are flattened using `_` as a separator (e.g. `address_city`). Null values
(`nothing`, `missing`) are written as empty cells.

Pass a context object `strategy` (e.g. [`CamelCase()`](@ref)) as the first argument to apply
global field-renaming to the column headers.

# Arguments
- `data::Vector{T}`: the rows to serialize.
- `strategy`: optional context object.

# Keyword arguments
- `delimiter::String = ","`: field separator character.
- `headers::Vector{String} = String[]`: explicit column order. When empty, all columns
  are included in field-declaration order.
- `with_names::Bool = true`: include a header row as the first line.

# Returns
A CSV-formatted `String`. Returns `""` if `data` is empty.

# Examples
```julia
julia> struct Person; name::String; age::Int; end

julia> to_csv([Person("Alice", 30), Person("Bob", 25)]) |> print
name,age
Alice,30
Bob,25

julia> to_csv([Person("Alice", 30)]; with_names=false) |> print
Alice,30
```

See also: [`from_csv`](@ref).
"""
function to_csv end

end
