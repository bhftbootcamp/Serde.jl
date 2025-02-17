module Serde

function deser end
function parse_value end

# Ser
export to_csv,
    to_json,
    to_pretty_json,
    to_query,
    to_toml,
    to_xml,
    to_yaml

# De
export deser_csv,
    deser_json,
    deser_query,
    deser_toml,
    deser_xml,
    deser_yaml

# Par
export parse_csv,
    parse_json,
    parse_query,
    parse_toml,
    parse_xml,
    parse_yaml

# Utl
export @serde,
    @serde_pascal_case,
    @serde_camel_case,
    @serde_kebab_case,
    to_flatten

include("Utl/Utl.jl")

#__ Ser

(ser_name(::Type{T}, ::Val{x})::Symbol) where {T,x} = x
(ser_value(::Type{T}, ::Val{x}, v::V)::V) where {T,x,V} = v
(ser_type(::Type{T}, v::V)::V) where {T,V} = v

(ser_ignore_field(::Type{T}, ::Val{x})::Bool) where {T,x} = false
(ser_ignore_field(::Type{T}, k::Val{x}, v::V)::Bool) where {T,x,V} = ser_ignore_field(T, k)

#__ De.jl

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

struct MissingKeyError <: DeserError
    key::Any
end

function Base.show(io::IO, e::MissingKeyError)
    return print(io, "KeyError: required key '$(e.key)' is missing or invalid.")
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

#__ Format

include("Csv/Csv.jl")
include("Json/Json.jl")
include("Query/Query.jl")
include("Toml/Toml.jl")
include("Xml/Xml.jl")
include("Yaml/Yaml.jl")

end
