module SerdeParquet

export parse_parquet, from_parquet, try_from_parquet, to_parquet

import ..ParseError, ..SerdeError, ..DefaultStrategy

"""
    parse_parquet
  
Decode Parquet bytes, an `IO` stream, or an on-disk file into a row-oriented
`Vector` of dictionaries without mapping to a target type.

Each element corresponds to one row; keys are the Parquet column names (as
`String`s) and values are the column's decoded Julia values (including
`missing` for nulls).

# Arguments
- `x`: a `Vector{UInt8}` holding raw Parquet bytes, or
- `io`: an `IO` stream positioned at the start of a Parquet file, or
- `path`: a filesystem path to a `.parquet` file.

# Keyword arguments
- `dict_type::Type{<:AbstractDict}`: concrete dict type used for each row
  (default `Dict{String,Any}`).
- Additional keyword arguments are forwarded to `Parquet2.Dataset`.

# Returns
A `Vector` of `dict_type` - one entry per data row.

# Throws
- [`ParseError`](@ref): if the input is not a valid Parquet file.

# Examples
```julia
julia> struct Row; name::String; age::Int; end

julia> bytes = to_parquet([Row("Alice", 30), Row("Bob", 25)]);

julia> parse_parquet(bytes)
2-element Vector{Dict{String, Any}}:
 Dict("name" => "Alice", "age" => 30)
 Dict("name" => "Bob",   "age" => 25)
```

See also: [`from_parquet`](@ref), [`try_from_parquet`](@ref).
"""
function parse_parquet end

"""
    from_parquet

Parse Parquet input and deserialize each row into type `T`, returning a `Vector{T}`.

Because Parquet is an inherently tabular (columnar) format, the target type
**must** be a `Vector{T}`. Passing a non-vector type raises `ArgumentError`.
`x` may be a `Vector{UInt8}`, an `IO`, or a filesystem path, exactly as accepted
by [`parse_parquet`](@ref).

# Arguments
- `::Type{Vector{T}}`: the target row-vector type. `Vector{Any}` and the bare
  `Vector` shortcut both return the raw dictionary rows produced by
  [`parse_parquet`](@ref).
- `x`: Parquet bytes, `IO`, or path.
- `strategy`: optional context object.

# Keyword arguments
- `dict_type::Type{<:AbstractDict}`: dict type used for intermediate rows
  (default `Dict{String,Any}`).
- Other keyword arguments are forwarded to `Parquet2.Dataset`.

# Returns
`Vector{T}` - one element per data row.

# Throws
- `ArgumentError`: if the target type is not a `Vector{T}`.
- [`ParseError`](@ref): if `x` is not valid Parquet.
- [`MissingFieldError`](@ref): if a required struct field is absent.
- [`TypeMismatchError`](@ref): if a column value cannot be coerced to the field type.

# Examples
```julia
julia> struct Row; name::String; age::Int; end

julia> bytes = to_parquet([Row("Alice", 30), Row("Bob", 25)]);

julia> from_parquet(Vector{Row}, bytes)
2-element Vector{Row}:
 Row("Alice", 30)
 Row("Bob", 25)
```

See also: [`try_from_parquet`](@ref), [`to_parquet`](@ref), [`parse_parquet`](@ref).
"""
function from_parquet end

"""
    try_from_parquet

Like [`from_parquet`](@ref) but returns a [`SerdeError`](@ref) instead of throwing on failure.

# Returns
- `Vector{T}` on success.
- A [`ParseError`](@ref) or [`DeserError`](@ref) subtype on failure.

See also: [`from_parquet`](@ref), [`SerdeError`](@ref).
"""
function try_from_parquet end

"""
    to_parquet

Serialize a vector of structs into Parquet bytes (or write them to `io`).

`data` is interpreted row-wise: every element becomes one row, and the
struct's field names — passed through [`Serde.ser_name`](@ref) — become column
names. Field values are converted via [`Serde.ser_value`](@ref) /
[`Serde.ser_type`](@ref); fields skipped by [`Serde.ser_skip`](@ref) are
omitted from the schema. Each column is automatically narrowed to the tightest
element type (with `missing` added when any value is `nothing` or `missing`).


# Arguments
- `data::AbstractVector`: rows to serialize. Must be **non-empty** — Parquet
  has no zero-row encoding.
- `io::IO`: optional sink to write the bytes to.
- `strategy`: optional context object.

# Keyword arguments
- Forwarded to `Parquet2.writefile` (e.g. `compression_codec`).

# Returns
- The 1-arg / 2-arg forms return `Vector{UInt8}` containing the Parquet file.
- The `IO`-sink forms write to `io` and return `nothing`.

# Throws
- `ArgumentError`: if `data` is empty, if its row type has no fields, or if
  every field is excluded by [`Serde.ser_skip`](@ref).

# Examples
```julia
julia> struct Row; name::String; age::Int; end

julia> bytes = to_parquet([Row("Alice", 30), Row("Bob", 25)]);

julia> from_parquet(Vector{Row}, bytes)
2-element Vector{Row}:
 Row("Alice", 30)
 Row("Bob", 25)
```

See also: [`from_parquet`](@ref).
"""
function to_parquet end

const _PARQUET_HINT = "Parquet support requires the `Parquet2` package. " *
                      "Run `import Pkg; Pkg.add(\"Parquet2\")` and then " *
                      "`import Parquet2` to activate the extension."

parse_parquet(args...; kw...)     = throw(ArgumentError(_PARQUET_HINT))
from_parquet(args...; kw...)      = throw(ArgumentError(_PARQUET_HINT))
try_from_parquet(args...; kw...)  = throw(ArgumentError(_PARQUET_HINT))
to_parquet(args...; kw...)        = throw(ArgumentError(_PARQUET_HINT))

end
