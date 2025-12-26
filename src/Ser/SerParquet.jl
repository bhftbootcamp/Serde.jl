module SerParquet

export to_parquet

using Parquet2
using Dates
using UUIDs
using Tables
import ..to_flatten, ..issimple

"""
    to_parquet(path::AbstractString, data::Vector{T}; kw...) -> Nothing

Writes `data` to a Parquet file at the specified `path`. Type `T` may be a dictionary or a custom type.
Nested structures will be flattened before writing.

## Keyword arguments
Additional keyword arguments can be found in [Parquet2.jl documentation](https://gitlab.com/ExpandingMan/Parquet2.jl)

## Examples

Writing a vector of structs to a Parquet file:

```julia-repl
julia> struct Record
           id::Int64
           name::String
           value::Float64
       end

julia> data = [
           Record(1, "Alice", 100.5),
           Record(2, "Bob", 200.3),
       ];

julia> to_parquet("output.parquet", data)
```

Writing a vector of dictionaries:

```julia-repl
julia> data = [
           Dict("id" => 1, "name" => "Alice", "value" => 100.5),
           Dict("id" => 2, "name" => "Bob", "value" => 200.3),
       ];

julia> to_parquet("output.parquet", data)
```
"""
function to_parquet(
    path::String,
    data::Vector{T};
    kw...
)::Nothing where {T}
    # Convert to a format compatible with Tables.jl
    # Parquet2 expects data that implements the Tables.jl interface
    if isempty(data)
        # Create empty parquet file with no columns
        Parquet2.writefile(path, (;); kw...)
    elseif T <: AbstractDict
        # Convert vector of dictionaries to named tuple of vectors (columnar format)
        # First flatten if needed
        processed_data = [to_flatten(item) for item in data]

        # Get all unique keys from all dictionaries
        all_keys = Set{String}()
        for item in processed_data
            if item isa AbstractDict
                union!(all_keys, string.(keys(item)))
            end
        end

        sorted_keys = sort(collect(all_keys))
        columns = Dict{Symbol,Vector}()

        for key in sorted_keys
            col_key = Symbol(key)
            # Collect values first to infer type
            values = []
            for item in processed_data
                if item isa AbstractDict
                    val = get(item, key, missing)
                    push!(values, val === nothing ? missing : val)
                else
                    push!(values, missing)
                end
            end
            # Store with inferred type
            columns[col_key] = values
        end

        # Convert to NamedTuple for Tables.jl compatibility
        tbl = NamedTuple{Tuple(Symbol.(sorted_keys))}(Tuple(columns[Symbol(k)] for k in sorted_keys))
        Parquet2.writefile(path, tbl; kw...)
    else
        # For structs, convert to columnar format using Tables.jl
        # Tables.columntable converts vector of structs to NamedTuple of vectors
        tbl = Tables.columntable(data)
        Parquet2.writefile(path, tbl; kw...)
    end

    return nothing
end

end
