import ..Ext

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
function deser_yaml(args...; kwargs...)
    Ext.YAML().deser_yaml(args...; kwargs...)
end

"""
    parse_yaml(x::AbstractString; kw...) -> Dict{String,Any}
    parse_yaml(x::Vector{UInt8}; kw...) -> Dict{String,Any}

Parse a YAML string `x` (or vector of UInt8) into a dictionary.

## Keyword arguments
You can see additional keyword arguments in YAML.jl package [repository](https://github.com/JuliaData/YAML.jl).

## Examples

```julia-repl
julia> yaml = \"\"\"
        string: qwerty
        date: 2024-01-01
        dict:
          dict_key_1: dict_value_1 #comment
          dict_key_2: dict_value_2
        list:
          - string: foo
            quoted: 'bar'
            float: 1.63
            int: 63
          - string: baz
            braces: '{{ dd }}'
        anchorTest: &myAnchor
          toSingleLine: >
            this text will be considered on a
            single line
          toMultiline: |
            this text will be considered
            on multiple lines
        aliasTest: *myAnchor
        \"\"\";

julia> parse_yaml(yaml)
Dict{String, Any} with 6 entries:
  "dict"       => Dict{String, Any}("dict_key_2"=>"dict_value_2", "dict_key_1"=>"dict_value_1")
  "string"     => "qwerty"
  "list"       => Dict{String, Any}[Dict("int"=>63, "string"=>"foo", "quoted"=>"bar", "float"=>1.63), Dict("string"=>"baz", "braces"=>"{{ dd }}")]
  "anchorTest" => Dict{String, Any}("toMultiline"=>"this text will be considered \\non multiple lines\\n", "toSingleLine"=>"this text will be considered on a single line\\n")
  "aliasTest"  => Dict{String, Any}("toMultiline"=>"this text will be considered \\non multiple lines\\n", "toSingleLine"=>"this text will be considered on a single line\\n")
  "date"       => Date("2024-01-01")
```
"""
function parse_yaml(args...; kwargs...)
    Ext.YAML().parse_yaml(args...; kwargs...)
end

"""
    to_yaml([f::Function], data) -> String

Serializes any `data` into a YAML multiline string.
This method support serialization of nested data like dictionaries or custom types.

## Specifying fields for serialization

If you want to serialize only specific fields of some custom type, you may define a special function `f`.
This function `f` must lead next signature:

```julia
f(::Type{CustomType}) = (:field_1, :field_2, ...)
```

Now `to_yaml(f, CustomType(...))` will serialize only specified fields `CustomType.field_1`, `CustomType.field_2`, etc.
You can also define multiple methods of `f` for nested custom data types, e.g:

```julia
# Custom type 'Foo' containing fields of other custom types 'bar::Bar' and 'baz::Baz'
custom_field_names(::Type{Foo}) = (:bar, :baz, ...)

# Another custom types
custom_field_names(::Type{Bar}) = (:data, ...)
custom_field_names(::Type{Baz}) = (:another_data, ...)
```

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

julia> to_yaml(Person(person_info, Pet("Buddy", 5))) |> print
info:
  marks:
    - "A+"
    - "B"
    - "A"
  id: 42
pet:
  name: "Buddy"
  age: 5

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

julia> to_yaml(custom_field_names, ManyFields(1, 2.0, "a", [true, false])) |> print
field: 1
simple_field: "a"

# Or you can use a lambda function

julia> to_yaml(x -> (:field, :simple_field), ManyFields(1, 2.0, "a", [true, false])) |> print
field: 1
simple_field: "a"
```
"""
function to_yaml(args...; kwargs...)
    Ext.YAML().to_yaml(args...; kwargs...)
end
