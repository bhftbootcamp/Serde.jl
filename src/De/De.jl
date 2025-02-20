# De/De

abstract type DeserError <: Exception end

struct ParamError <: DeserError
    key::Any
end

function Base.show(io::IO, e::ParamError)
    return print(
        io,
        "ParamError: parameter '$(e.key)' was not passed or has the value 'nothing'",
    )
end

struct WrongType <: DeserError
    maintype::DataType
    key::Any
    value::Any
    from_type::Any
    to_type::Any
end

function Base.show(io::IO, e::WrongType)
    return print(
        io,
        "WrongType: for '$(e.maintype)' value '$(e.value)' has wrong type '$(e.key)::$(e.from_type)', must be '$(e.key)::$(e.to_type)'",
    )
end

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
to_deser(::Type{T}, x) where {T} = deser(T, x)

to_deser(::Type{Nothing}, x) = nothing
to_deser(::Type{Missing}, x) = missing

include("DeJson.jl")
using .DeJson

include("DeToml.jl")
using .DeToml

include("DeQuery.jl")
using .DeQuery

include("DeCsv.jl")
using .DeCsv

include("DeXml.jl")
using .DeXml

include("DeYaml.jl")
using .DeYaml
