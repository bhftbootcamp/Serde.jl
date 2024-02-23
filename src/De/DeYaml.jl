module DeYaml

export deser_yaml

using ..ParYaml
import ..to_deser

"""
    deser_yaml(::Type{T}, x) -> T

Creates a new object of type `T` and fill it with values from YAML formated string `x` (or vector of UInt8).

Keyword arguments `kw` is the same as in [`parse_yaml`](@ref).

## Examples
```julia-repl
julia> struct Numeric
           i::Int64
           f::Float64
       end

julia> struct Data
           s::String
           n::Numeric
           v::AbstractVector
           b::Bool
           d::AbstractDict
       end

julia> yaml = \"\"\"
        s: foobar
        n:
          i: 163
          f: 1.63
        v:
          - a
          - b
          - c
        b: True
        d:
          d1: foo
          d2: bar
        \"\"\";

julia> deser_yaml(Data, yaml)
Data("foobar", Numeric(163, 1.63), ["a", "b", "c"], true, Dict{String, Any}("d1" => "foo", "d2" => "bar"))
```
"""
function deser_yaml(::Type{T}, x; kw...) where {T}
    return to_deser(T, parse_yaml(x; kw...))
end

deser_yaml(::Type{Nothing}, _) = nothing
deser_yaml(::Type{Missing}, _) = missing

function deser_yaml(f::Function, x; kw...)
    object = parse_yaml(x; kw...)
    return to_deser(f(object), object)
end

end
