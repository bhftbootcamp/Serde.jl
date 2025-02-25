module SerYaml

export to_yaml

using Dates
using UUIDs
using ..Serde

const YAML_NULL = "null"
const INDENT = "  "
const DOUBLE_QUOTE = '"'
const SINGLE_QUOTE = "'"
const INDENT_TYPES = [Pair, AbstractDict, AbstractVector, Tuple, NamedTuple, AbstractSet]
const NEEDESCAPE = Set(['"', '\\', '\b', '\f', '\n', '\r', '\t'])

indent(l::Int64)::String = "\n" * (INDENT^l)

function yaml_value!(io::IOBuffer, f::Function, val::AbstractString; is_key::Bool = false, kw...)::Nothing
    if any(c -> c in NEEDESCAPE || iscntrl(c), val)
        return print(io, DOUBLE_QUOTE, escape_string(val), DOUBLE_QUOTE)
    else
        return is_key ? print(io, val) : print(io, DOUBLE_QUOTE, val, DOUBLE_QUOTE)
    end
end

function yaml_value!(io::IOBuffer, f::Function, val::Symbol; kw...)::Nothing
    return yaml_value!(io, f, string(val); kw...)
end

function yaml_value!(io::IOBuffer, f::Function, val::TimeType; kw...)::Nothing
    return yaml_value!(io, f, string(val); kw...)
end

function yaml_value!(io::IOBuffer, f::Function, val::UUID; kw...)::Nothing
    return yaml_value!(io, f, string(val); kw...)
end

function yaml_value!(io::IOBuffer, f::Function, val::AbstractChar; kw...)::Nothing
    return print(io, SINGLE_QUOTE, val, SINGLE_QUOTE)
end

function yaml_value!(io::IOBuffer, f::Function, val::Bool; kw...)::Nothing
    return print(io, val)
end

function yaml_value!(io::IOBuffer, f::Function, val::Number; kw...)::Nothing
    return if isnan(val)
        print(io, ".nan")
    elseif isinf(val)
        print(io, ".inf")
    else
        print(io, val)
    end
end

function yaml_value!(io::IOBuffer, f::Function, val::Enum; kw...)::Nothing
    return print(io, val)
end

function yaml_value!(io::IOBuffer, f::Function, val::Missing; kw...)::Nothing
    return print(io, YAML_NULL)
end

function yaml_value!(io::IOBuffer, f::Function, val::Nothing; kw...)::Nothing
    return print(io, YAML_NULL)
end

function yaml_value!(io::IOBuffer, f::Function, val::Type; kw...)::Nothing
    return print(io, val)
end

function yaml_value!(io::IOBuffer, f::Function, val::Function; kw...)::Nothing
    throw("Can't serialize type 'Function' to YAML data")
end

function yaml_value!(io::IOBuffer, f::Function, val::Pair; l::Int64, skip_lf::Bool = false, kw...)::Nothing
    print(io, skip_lf ? "" : indent(l))
    yaml_value!(io, f, first(val); l = l + 1, is_key = true, kw...)
    print(io, ": ")
    yaml_value!(io, f, last(val); l = l + 1, kw...)
    return print(io)
end

function yaml_value!(io::IOBuffer, f::Function, val::AbstractDict; l::Int64, skip_lf::Bool = false, kw...)::Nothing
    next = iterate(val)
    print(io, skip_lf ? "" : indent(l))
    while next !== nothing
        (k, v), index = next
        yaml_value!(io, f, k; l = l + 1, is_key = true, kw...)
        print(io, any(map(t -> isa(v, t), INDENT_TYPES)) ? ":" : ": ")
        yaml_value!(io, f, v; l = l + 1, kw...)
        next = iterate(val, index)
        next === nothing || print(io, indent(l))
    end
    return print(io)
end

function yaml_value!(io::IOBuffer, f::Function, val::AbstractVector; l::Int64, skip_lf::Bool = false, kw...)::Nothing
    next = iterate(val)
    print(io, skip_lf ? "" : indent(l))
    while next !== nothing
        item, index = next
        print(io, "- ")
        yaml_value!(io, f, item; l = l + 1, skip_lf = true, kw...)
        next = iterate(val, index)
        next === nothing || print(io, indent(l))
    end
    return print(io)
end

function yaml_value!(io::IOBuffer, f::Function, val::Tuple; l::Int64, skip_lf::Bool = false, kw...)::Nothing
    next = iterate(val)
    print(io, skip_lf ? "" : indent(l))
    while next !== nothing
        item, index = next
        print(io, "- ")
        yaml_value!(io, f, item; l = l + 1, skip_lf = true, kw...)
        next = iterate(val, index)
        next === nothing || print(io, indent(l))
    end
    return print(io)
end

function yaml_value!(io::IOBuffer, f::Function, val::NamedTuple; l::Int64, skip_lf::Bool = false, kw...)::Nothing
    names = keys(val)
    print(io, skip_lf ? "" : indent(l))
    next = iterate(names)
    next_value = iterate(val)
    while next !== nothing
        item, index = next
        item_value, index_value = next_value
        yaml_value!(io, f, item; l = l + 1, is_key = true, kw...)
        print(io, ": ")
        yaml_value!(io, f, item_value; l = l + 1, skip_lf = true, kw...)
        next = iterate(names, index)
        next_value = iterate(val, index_value)
        next === nothing || print(io, indent(l))
    end
    return print(io)
end

function yaml_value!(io::IOBuffer, f::Function, val::AbstractSet; l::Int64, skip_lf::Bool = false, kw...)::Nothing
    next = iterate(val)
    print(io, skip_lf ? "" : indent(l))
    while next !== nothing
        item, index = next
        print(io, "- ")
        yaml_value!(io, f, item; l = l + 1, skip_lf = true, kw...)
        next = iterate(val, index)
        next === nothing || print(io, indent(l))
    end
    return print(io)
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

function yaml_value!(io::IOBuffer, f::Function, val::T; l::Int64, skip_lf::Bool = false, kw...)::Nothing where {T}
    next = iterate(f(T))
    print(io, skip_lf ? "" : indent(l))
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
        (index - ignore_count) == 2 || print(io, indent(l))
        yaml_value!(io, f, k; l = l + 1, is_key = true, kw...)
        print(io, any(map(t -> isa(v, t), INDENT_TYPES)) ? ":" : ": ")
        yaml_value!(io, f, v; l = l + 1, kw...)
        next = iterate(f(T), index)
    end
    return print(io)
end

function yaml_value!(io::IOBuffer, val::T; l::Int64, kw...)::Nothing where {T}
    return yaml_value!(io, fieldnames, val; l = 0, kw...)
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
function to_yaml(x...; kw...)::String
    io = IOBuffer()
    try
        yaml_value!(io, x...; l = 0, skip_lf = true, kw...)
        print(io, "\n")
        return String(take!(io))
    finally
        close(io)
    end
end

end
