module DeParquet

export deser_parquet

using ..ParParquet
import ..to_deser

"""
    deser_parquet(::Type{T}, path::AbstractString; kw...) -> Vector{T}

Reads a Parquet file from `path` and creates a vector of objects of type `T` filled with values from the file.

Keyword arguments `kw` are the same as in [`parse_parquet`](@ref).

## Examples
```julia-repl
julia> struct Data
           id::Int64
           name::String
           value::Float64
       end

julia> # Assume data.parquet file exists with matching schema
julia> records = deser_parquet(Data, "data.parquet")
2-element Vector{Data}:
 Data(1, "Alice", 100.5)
 Data(2, "Bob", 200.3)
```
"""
function deser_parquet(::Type{T}, path::S; kw...) where {T,S<:AbstractString}
    return to_deser(Vector{T}, parse_parquet(path; kw...))
end

deser_parquet(::Type{Nothing}, _) = nothing
deser_parquet(::Type{Missing}, _) = missing

function deser_parquet(f::Function, path; kw...)
    object = parse_parquet(path; kw...)
    return to_deser(f(object), object)
end

end
