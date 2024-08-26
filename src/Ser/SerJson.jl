module SerJson

export to_json
export to_pretty_json

using Dates
using UUIDs
using ..Serde

const JSON_NULL = "null"
const INDENT = "  "
const NEEDESCAPE = Set(['"', '\\', '\b', '\f', '\n', '\r', '\t'])
const DOUBLE_QUOTE = '"'

indent(l::Int64)::String = l > -1 ? "\n" * (INDENT^l) : ""

function json_value!(io::IOBuffer, f::Function, val::AbstractString; kw...)::Nothing
    if any(c -> c in NEEDESCAPE || iscntrl(c), val)
        print(io, DOUBLE_QUOTE, escape_string(val), DOUBLE_QUOTE)
    else
        print(io, DOUBLE_QUOTE, val, DOUBLE_QUOTE)
    end
end

function json_value!(io::IOBuffer, f::Function, val::Symbol; kw...)::Nothing
    return json_value!(io, f, string(val); kw...)
end

function json_value!(io::IOBuffer, f::Function, val::TimeType; kw...)::Nothing
    return json_value!(io, f, string(val); kw...)
end

function json_value!(io::IOBuffer, f::Function, val::UUID; kw...)::Nothing
    return json_value!(io, f, string(val); kw...)
end

function json_value!(io::IOBuffer, f::Function, val::AbstractChar; kw...)::Nothing
    return print(io, DOUBLE_QUOTE, val, DOUBLE_QUOTE)
end

function json_value!(io::IOBuffer, f::Function, val::Bool; kw...)::Nothing
    return print(io, val)
end

function json_value!(io::IOBuffer, f::Function, val::Number; kw...)::Nothing
    return isnan(val) || isinf(val) ? print(io, JSON_NULL) : print(io, val)
end

function json_value!(io::IOBuffer, f::Function, val::Enum; kw...)::Nothing
    return print(io, DOUBLE_QUOTE, val, DOUBLE_QUOTE)
end

function json_value!(io::IOBuffer, f::Function, val::Missing; kw...)::Nothing
    return print(io, JSON_NULL)
end

function json_value!(io::IOBuffer, f::Function, val::Nothing; kw...)::Nothing
    return print(io, JSON_NULL)
end

function json_value!(io::IOBuffer, f::Function, val::Type; kw...)::Nothing
    return print(io, DOUBLE_QUOTE, val, DOUBLE_QUOTE)
end

function json_value!(io::IOBuffer, f::Function, val::Pair; l::Int64, kw...)::Nothing
    print(io, "{", indent(l))
    json_value!(io, f, first(val); l = l + (l != -1), kw...)
    print(io, ":")
    json_value!(io, f, last(val); l = l + (l != -1), kw...)
    return print(io, indent(l - 1), "}")
end

function json_value!(io::IOBuffer, f::Function, val::AbstractDict; l::Int64, kw...)::Nothing
    next = iterate(val)
    print(io, "{", indent(l))
    while next !== nothing
        (k, v), index = next
        json_value!(io, f, k; l = l + (l != -1), kw...)
        print(io, ":")
        json_value!(io, f, v; l = l + (l != -1), kw...)
        next = iterate(val, index)
        next === nothing || print(io, ",", indent(l))
    end
    return print(io, indent(l - 1), "}")
end

function json_value!(io::IOBuffer, f::Function, val::AbstractVector; l::Int64, kw...)::Nothing
    next = iterate(val)
    print(io, "[", indent(l))
    while next !== nothing
        item, index = next
        json_value!(io, f, item; l = l + (l != -1), kw...)
        next = iterate(val, index)
        next === nothing || print(io, ",", indent(l))
    end
    return print(io, indent(l - 1), "]")
end

function json_value!(io::IOBuffer, f::Function, val::Tuple; l::Int64, kw...)::Nothing
    next = iterate(val)
    print(io, "[", indent(l))
    while next !== nothing
        item, index = next
        json_value!(io, f, item; l = l + (l != -1), kw...)
        next = iterate(val, index)
        next === nothing || print(io, ",", indent(l))
    end
    return print(io, indent(l - 1), "]")
end

function json_value!(io::IOBuffer, f::Function, val::AbstractSet; l::Int64, kw...)::Nothing
    next = iterate(val)
    print(io, "[", indent(l))
    while next !== nothing
        item, index = next
        json_value!(io, f, item; l = l + (l != -1), kw...)
        next = iterate(val, index)
        next === nothing || print(io, ",", indent(l))
    end
    return print(io, indent(l - 1), "]")
end

function json_value!(io::IOBuffer, f::Function, A::AbstractArray{<:Any,n}; l::Int64, kw...)::Nothing where {n}
    print(io, "[", indent(l))
    newdims = ntuple(_ -> :, n - 1)
    first = true
    for j in axes(A, n)
        first || print(io, ",", indent(l))
        first = false
        json_value!(io, f, view(A, newdims..., j); l = l + (l != -1), kw...)
    end
    print(io, indent(l - 1), "]")
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

function json_value!(io::IOBuffer, f::Function, val::T; l::Int64, kw...)::Nothing where {T}
    next = iterate(f(T))
    print(io, "{", indent(l))
    ignore_count::Int64 = 0
    while next !== nothing
        field, index = next
        k = ser_name(T, Val(field))
        v = ser_type(T, ser_value(T, Val(field), getfield(val, field)))
        if ser_ignore_null(T) && isnull(v) || ser_ignore_field(T, Val(field), v)
            next = iterate(f(T), index)
            ignore_count += 1
            continue
        end
        (index - ignore_count) == 2 || print(io, ",", indent(l))
        json_value!(io, f, k; l = l + (l != -1), kw...)
        print(io, ":")
        json_value!(io, f, v; l = l + (l != -1), kw...)
        next = iterate(f(T), index)
    end
    return print(io, indent(l - 1), "}")
end

function json_value!(io::IOBuffer, val::T; l::Int64, kw...)::Nothing where {T}
    return json_value!(io, fieldnames, val; l = l, kw...)
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
function to_json(x...; kw...)::String
    io = IOBuffer()
    try
        json_value!(io, x...; l = -1, kw...)
        return String(take!(io))
    finally
        close(io)
    end
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
function to_pretty_json(x...; kw...)::String
    io = IOBuffer()
    try
        json_value!(io, x...; l = 1, kw...)
        return String(take!(io))
    finally
        close(io)
    end
end

end
