module DeToml

export deser_toml

using ..ParToml
import ..to_deser

"""
    deser_toml(::Type{T}, x) -> T

Creates a new object of type `T` and fill it with values from TOML formated string `x` (or vector of UInt8).

See also [`parse_toml`](@ref).

## Examples
```julia-repl
julia> struct Point
           x::Int64
           y::Int64
       end

julia> struct MyPlot
           tag::String
           points::Vector{Point}
       end

julia> toml = \"\"\"
       tag = "line"
       [[points]]
       x = 1
       y = 0
       [[points]]
       x = 2
       y = 3
       \"\"\";

julia> deser_toml(MyPlot, toml)
MyPlot("line", Point[Point(1, 0), Point(2, 3)])
```
"""
function deser_toml(::Type{T}, x; kw...) where {T}
    return to_deser(T, parse_toml(x; kw...))
end

deser_toml(::Type{Nothing}, _) = nothing
deser_toml(::Type{Missing}, _) = missing

function deser_toml(f::Function, x; kw...)
    object = parse_toml(x; kw...)
    return to_deser(f(object), object)
end

end
