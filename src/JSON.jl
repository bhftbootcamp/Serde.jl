module JSON

import ..Serde

export to_json,
       to_pretty_json,
       deser_json,
       parse_json

function err_JSON()
    error("""JSON extension isn't loaded, please ensure that the 'JSON' package is imported
          into your environment""")
end

(isnull(::Any)::Bool) = false
(isnull(v::Missing)::Bool) = true
(isnull(v::Nothing)::Bool) = true
(isnull(v::Float64)::Bool) = isnan(v) || isinf(v)

(ser_name(::Type{T}, k::Val{x})::Symbol) where {T,x} = Serde.ser_name(T, k)
(ser_value(::Type{T}, k::Val{x}, v::V)) where {T,x,V} = Serde.ser_value(T, k, v)
(ser_type(::Type{T}, v::V)) where {T,V} = Serde.ser_type(T, v)

(ser_ignore_field(::Type{T}, k::Val{x})::Bool) where {T,x} = Serde.ser_ignore_field(T, k)
(ser_ignore_field(::Type{T}, k::Val{x}, v::V)::Bool) where {T,x,V} = ser_ignore_field(T, k)
(ser_ignore_null(::Type{T})::Bool) where {T} = false

"""
    JsonSyntaxError <: Exception

Exception thrown when a [`parse_json`](@ref) fails due to incorrect JSON syntax or any underlying error that occurs during parsing.

## Fields
- `message::String`: The error message.
- `exception::Exception`: The catched exception.
"""
struct JsonSyntaxError <: Exception
    message::String
    exception::Exception
end

"""
    to_json([f::Function], data) -> String

Serializes any `data` into a flat JSON string.
This method support serialization of nested data like dictionaries or custom types.

## Specifying fields for serialization

If you want to serialize only specific fields of some custom type, you may define a special function `f`.
This function `f` must lead next signature:

```julia
f(::Type{CustomType}) = (:field_1, :field_2, ...)
```

Now `to_json(f, CustomType(...))` will serialize only specified fields `CustomType.field_1`, `CustomType.field_2`, etc.
You can also define multiple methods of `f` for nested custom data types, e.g:

```julia
# Custom type 'Foo' containing fields of other custom types 'bar::Bar' and 'baz::Baz'
custom_field_names(::Type{Foo}) = (:bar, :baz, ...)

# Another custom types
custom_field_names(::Type{Bar}) = (:data, ...)
custom_field_names(::Type{Baz}) = (:another_data, ...)
```

See also [`to_pretty_json`](@ref).

## Examples

```julia-repl
julia> struct Pet
           name::String
           age::Int64
       end

julia> struct Person
           info::Dict{String,Any}
           pet::Pet
       end

julia> person_info = Dict("id" => 42, "marks" => ["A+", "B", "A"]);

julia> to_json(Person(person_info, Pet("Buddy", 5))) |> print
{"info":{"marks":["A+","B","A"],"id":42},"pet":{"name":"Buddy","age":5}}
```

Now, lets select some specific fields from custom type

```julia-repl
julia> struct ManyFields
           field::Int64
           another_field::Float64
           simple_field::String
           fld::Vector{Bool}
       end

julia> custom_field_names(::Type{ManyFields}) = (:field, :simple_field)

julia> to_json(custom_field_names, ManyFields(1, 2.0, "a", [true, false])) |> print
{"field":1,"simple_field":"a"}

# Or you can use a lambda function

julia> to_json(x -> (:field, :simple_field), ManyFields(1, 2.0, "a", [true, false])) |> print
{"field":1,"simple_field":"a"}
```
"""
function to_json()
    err_JSON()
end

"""
    to_pretty_json([f::Function], data) -> String

Do the same as [`to_json`](@ref) but return pretty JSON string.

```julia-repl
julia> struct Pet
           name::String
           age::Int64
       end

julia> struct Person
           info::Dict{String,Any}
           pet::Pet
       end

julia> person_info = Dict("id" => 42, "marks" => ["A+", "B", "A"]);

julia> to_pretty_json(Person(person_info, Pet("Buddy", 5))) |> print
{
  "info":{
    "marks":[
      "A+",
      "B",
      "A"
    ],
    "id":42
  },
  "pet":{
    "name":"Buddy",
    "age":5
  }
}
```
"""
function to_pretty_json()
    err_JSON()
end

"""
    deser_json(::Type{T}, x; kw...) -> T

Creates a new object of type `T` and fill it with values from JSON formated string `x` (or vector of UInt8).

Keyword arguments `kw` is the same as in [`parse_json`](@ref).

## Examples
```julia-repl
julia> struct Record
           count::Float64
       end

julia> struct Data
           id::Int64
           name::String
           body::Record
       end

julia> json = \"\"\" {"body":{"count":100.0},"name":"json","id":100} \"\"\";

julia> deser_json(Data, json)
Data(100, "json", Record(100.0))
```
"""
function deser_json()
    err_JSON()
end

"""
    parse_json(x::AbstractString; kw...) -> Dict{String,Any}
    parse_json(x::Vector{UInt8}; kw...) -> Dict{String,Any}

Parse a JSON string `x` (or vector of UInt8) into a dictionary.

## Keyword arguments
You can see additional keyword arguments in JSON.jl package [documentation](https://github.com/JuliaIO/JSON.jl?tab=readme-ov-file#documentation).

## Examples

```julia-repl
julia> json = \"\"\"
        {
            "number": 123,
            "vector": [1, 2, 3],
            "dictionary":
            {
                "string": "123"
            }
        }
       \"\"\";

julia> parse_json(json)
Dict{String, Any} with 3 entries:
  "number"     => 123
  "vector"     => Any[1, 2, 3]
  "dictionary" => Dict{String, Any}("string"=>"123")
```
"""
function parse_json()
    err_JSON()
end

end
