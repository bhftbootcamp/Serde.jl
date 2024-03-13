module SerJson

export to_json
export to_pretty_json

using Dates
import ..ser_name,
    ..ser_value,
    ..ser_type,
    ..ignore_null,
    ..ignore_field

const JSON_NULL = "null"
const INDENT = "  "

# escaped string

const NEEDESCAPE = Set{UInt8}(UInt8['"', '\\', '\b', '\f', '\n', '\r', '\t'])

function escape_char(b)
    b == UInt8('"')  && return UInt8('"')
    b == UInt8('\\') && return UInt8('\\')
    b == UInt8('\b') && return UInt8('b')
    b == UInt8('\f') && return UInt8('f')
    b == UInt8('\n') && return UInt8('n')
    b == UInt8('\r') && return UInt8('r')
    b == UInt8('\t') && return UInt8('t')
    return 0x00
end

function escaped(b)
    if b == UInt8('/')
        return UInt8[UInt8('/')]
    elseif b >= 0x80
        return UInt8[b]
    elseif b in NEEDESCAPE
        return UInt8[UInt8('\\'), escape_char(b)]
    elseif iscntrl(Char(b))
        return UInt8[UInt8('\\'), UInt8('u'), Base.string(b, base = 16, pad = 4)...]
    else
        return UInt8[b]
    end
end

const ESCAPECHARS = Vector{UInt8}[escaped(b) for b = 0x00:0xff]

const ESCAPELENS = Int64[length(x) for x in ESCAPECHARS]

function escape_length(str)
    x = 0
    l = ncodeunits(str)
    @simd for i = 1:l
        @inbounds len = ESCAPELENS[codeunit(str, i)+1]
        x += len
    end
    return x
end

indent(l::Int64)::String = l > -1 ? "\n" * (INDENT^l) : ""

function json_value!(buf::IOBuffer, f::Function, val::AbstractString; kw...)::Nothing
    if escape_length(val) == ncodeunits(val)
        return print(buf, '\"', val, '\"')
    else
        return print(buf, '\"', escape_string(val), '\"')
    end
end

function json_value!(buf::IOBuffer, f::Function, val::Symbol; kw...)::Nothing
    return json_value!(buf, f, string(val); kw...)
end

function json_value!(buf::IOBuffer, f::Function, val::TimeType; kw...)::Nothing
    return json_value!(buf, f, string(val); kw...)
end

function json_value!(buf::IOBuffer, f::Function, val::AbstractChar; kw...)::Nothing
    return print(buf, '\"', val, '\"')
end

function json_value!(buf::IOBuffer, f::Function, val::Bool; kw...)::Nothing
    return print(buf, val)
end

function json_value!(buf::IOBuffer, f::Function, val::Number; kw...)::Nothing
    return isnan(val) || isinf(val) ? print(buf, JSON_NULL) : print(buf, val)
end

function json_value!(buf::IOBuffer, f::Function, val::Enum; kw...)::Nothing
    return print(buf, '\"', val, '\"')
end

function json_value!(buf::IOBuffer, f::Function, val::Missing; kw...)::Nothing
    return print(buf, JSON_NULL)
end

function json_value!(buf::IOBuffer, f::Function, val::Nothing; kw...)::Nothing
    return print(buf, JSON_NULL)
end

function json_value!(buf::IOBuffer, f::Function, val::Type; kw...)::Nothing
    return print(buf, '\"', val, '\"')
end

function json_value!(buf::IOBuffer, f::Function, val::Pair; l::Int64, kw...)::Nothing
    print(buf, "{", indent(l))
    json_value!(buf, f, first(val); l = l + (l != -1), kw...)
    print(buf, ":")
    json_value!(buf, f, last(val); l = l + (l != -1), kw...)
    return print(buf, indent(l - 1), "}")
end

function json_value!(buf::IOBuffer, f::Function, val::AbstractDict; l::Int64, kw...)::Nothing
    next = iterate(val)
    print(buf, "{", indent(l))
    while next !== nothing
        (k, v), index = next
        json_value!(buf, f, k; l = l + (l != -1), kw...)
        print(buf, ":")
        json_value!(buf, f, v; l = l + (l != -1), kw...)
        next = iterate(val, index)
        next === nothing || print(buf, ",", indent(l))
    end
    return print(buf, indent(l - 1), "}")
end

function json_value!(buf::IOBuffer, f::Function, val::AbstractVector; l::Int64, kw...)::Nothing
    next = iterate(val)
    print(buf, "[", indent(l))
    while next !== nothing
        item, index = next
        json_value!(buf, f, item; l = l + (l != -1), kw...)
        next = iterate(val, index)
        next === nothing || print(buf, ",", indent(l))
    end
    return print(buf, indent(l - 1), "]")
end

function json_value!(buf::IOBuffer, f::Function, val::Tuple; l::Int64, kw...)::Nothing
    next = iterate(val)
    print(buf, "[", indent(l))
    while next !== nothing
        item, index = next
        json_value!(buf, f, item; l = l + (l != -1), kw...)
        next = iterate(val, index)
        next === nothing || print(buf, ",", indent(l))
    end
    return print(buf, indent(l - 1), "]")
end

function json_value!(buf::IOBuffer, f::Function, val::AbstractSet; l::Int64, kw...)::Nothing
    next = iterate(val)
    print(buf, "[", indent(l))
    while next !== nothing
        item, index = next
        json_value!(buf, f, item; l = l + (l != -1), kw...)
        next = iterate(val, index)
        next === nothing || print(buf, ",", indent(l))
    end
    return print(buf, indent(l - 1), "]")
end

(isnull(::Any)::Bool) = false
(isnull(v::Missing)::Bool) = true
(isnull(v::Nothing)::Bool) = true
(isnull(v::Float64)::Bool) = isnan(v) || isinf(v)

function json_value!(buf::IOBuffer, f::Function, val::T; l::Int64, kw...)::Nothing where {T}
    next = iterate(f(T))
    print(buf, "{", indent(l))
    ignore_count::Int64 = 0
    while next !== nothing
        field, index = next
        k = ser_name(T, Val(field))
        v = ser_type(T, ser_value(T, Val(field), getfield(val, field)))
        if ignore_null(T) && isnull(v) || ignore_field(T, Val(field), v)
            next = iterate(f(T), index)
            ignore_count += 1
            continue
        end
        (index - ignore_count) == 2 || print(buf, ",", indent(l))
        json_value!(buf, f, k; l = l + (l != -1), kw...)
        print(buf, ":")
        json_value!(buf, f, v; l = l + (l != -1), kw...)
        next = iterate(f(T), index)
    end
    return print(buf, indent(l - 1), "}")
end

function json_value!(buf::IOBuffer, val::T; l::Int64, kw...)::Nothing where {T}
    return json_value!(buf, fieldnames, val; l = l, kw...)
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
    buf = IOBuffer()
    json_value!(buf, x...; l = -1, kw...)
    return String(take!(buf))
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
    buf = IOBuffer()
    json_value!(buf, x...; l = 1, kw...)
    return String(take!(buf))
end

end
