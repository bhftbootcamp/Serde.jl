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
julia> struct Status
           id::Int64
           value::Float64
       end

julia> struct Server
           name::String
           status::Status
           data::Vector
           online::Bool
           users::Dict{String,Int64}
       end

julia> yaml = \"\"\"
       name: cloud_server
       status:
         id: 42
         value: 12.34
       data:
         - 1
         - 2
         - 3
       online: True
       users:
         Kevin: 1
         George: 2
       \"\"\";

julia> deser_yaml(Server, yaml)
Server("cloud_server", Status(42, 12.34), [1, 2, 3], true, Dict("Kevin" => 1, "George" => 2))
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
