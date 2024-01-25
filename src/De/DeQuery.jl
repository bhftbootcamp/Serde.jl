module DeQuery

export deser_query

using ..ParQuery
import ..to_deser

"""
    deser_query(::Type{T}, x; kw...) -> T

Creates a new object of type `T` and fill it with values from Query formated string `x` (or vector of UInt8).

Keyword arguments `kw` is the same as in [`parse_query`](@ref).

## Examples
```julia-repl
julia> struct Person
           age::Int64
           name::String
           pets::Vector{String}
       end

julia> query = "age=20&name=Nancy&pets=[Cat,Dog]";

julia> deser_query(Person, query)
Person(20, "Nancy", ["Cat", "Dog"])
```
"""
function deser_query(::Type{T}, x; kw...) where {T}
    return to_deser(T, parse_query(x; backbone=T, kw...))
end

deser_query(::Type{Nothing}, _) = nothing
deser_query(::Type{Missing}, _) = missing

function deser_query(f::Function, x; kw...)
    object = parse_query(x; kw...)
    return to_deser(f(object), object)
end

end
