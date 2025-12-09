# De/De


include("DeserChain.jl")

include("Deser.jl")

"""
    Serde.to_deser(::Type{T}, x) -> T

Creates a new object of type `T` with values corresponding to the key-value pairs of the dictionary `x`.

## Examples
```julia-repl
julia> struct Info
           id::Int64
           salary::Int64
       end

julia> struct Person
           name::String
           age::Int64
           info::Info
       end

julia> info_data = Dict("id" => 12, "salary" => 2500);

julia> person_data = Dict("name" => "Michael", "age" => 25, "info" => info_data);

julia> Serde.to_deser(Person, person_data)
Person("Michael", 25, Info(12, 2500))
```
"""

import ..Strategy

function deser(::Type{T}, parser::Strategy.AbstractParserStrategy, x; kw...) where {T}
    return to_deser(T, Strategy.parse(parser, x; kw...))
end

function deser(f::Function, parser::Strategy.AbstractParserStrategy, x; kw...)
    object = Strategy.parse(parser, x; kw...)
    return to_deser(f(object), object)
end
