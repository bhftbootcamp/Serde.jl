module ParParquet

export ParquetSyntaxError
export parse_parquet

using Parquet2
using Tables

"""
    ParquetSyntaxError <: Exception

Exception thrown when a [`parse_parquet`](@ref) fails due to incorrect Parquet file format or any underlying error that occurs during parsing.

## Fields
- `message::String`: The error message.
- `exception::Exception`: The catched exception.
"""
struct ParquetSyntaxError <: Exception
    message::String
    exception::Exception
end

Base.show(io::IO, e::ParquetSyntaxError) = print(io, e.message, ", caused by: ", e.exception)

"""
    parse_parquet(path::AbstractString; kw...) -> Vector{NamedTuple}

Parse a Parquet file from `path` into a vector of named tuples, where keys are column names and values are corresponding cell values.

## Keyword arguments
Additional keyword arguments can be found in [Parquet2.jl documentation](https://gitlab.com/ExpandingMan/Parquet2.jl).

## Examples

```julia-repl
julia> using Serde

julia> # Assume data.parquet exists
julia> data = parse_parquet("data.parquet");

julia> first(data)
(id = 1, name = "Alice", value = 100.5)
```
"""
function parse_parquet end

function parse_parquet(path::S; kw...) where {S<:AbstractString}
    try
        ds = Parquet2.Dataset(path; kw...)
        # Convert to vector of NamedTuples for consistency with other parsers
        # Use Tables.rows to iterate over rows
        return collect(Tables.rowtable(ds))
    catch e
        throw(ParquetSyntaxError("invalid Parquet file format", e))
    end
end

end
