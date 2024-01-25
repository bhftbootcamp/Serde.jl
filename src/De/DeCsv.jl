module DeCsv

export deser_csv

using ..ParCsv
import ..to_deser

"""
    deser_csv(::Type{T}, x; kw...) -> Vector{T}

Creates a new object of type `T` and fill it with values from CSV formated string `x` (or vector of UInt8).

Keyword arguments `kw` is the same as in [`parse_csv`](@ref).

## Examples
```julia-repl
julia> struct Data
           id::Int64
           name::String
           grade::Float64
       end

julia> csv = \"\"\"
       "id","name","grade"
       1,"Fred",78.2
       2,"Benny",82.0
       \"\"\";

julia> deser_csv(Data, csv)
2-element Vector{Data}:
 Data(1, "Fred", 78.2)
 Data(2, "Benny", 82.0)
```
"""
function deser_csv(::Type{T}, x; kw...) where {T}
    return to_deser(Vector{T}, parse_csv(x; kw...))
end

deser_csv(::Type{Nothing}, _) = nothing
deser_csv(::Type{Missing}, _) = missing

function deser_csv(f::Function, x; kw...)
    object = parse_csv(x; kw...)
    return to_deser(f(object), object)
end

end
