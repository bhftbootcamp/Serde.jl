module SerYaml

export to_yaml

using Dates
using Serde
using UUIDs

const YAML_NULL = "null"
const INDENT = "  "
const INDENT_TYPES = [Pair, AbstractDict, AbstractVector, Tuple, NamedTuple, AbstractSet]

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

indent(l::Int64)::String = "\n" * (INDENT^l)

function yaml_value!(buf::IOBuffer, f::Function, val::AbstractString; is_key::Bool = false, kw...)::Nothing
    if escape_length(val) == ncodeunits(val)
        return is_key ? print(buf, val) : print(buf, "\"", val, "\"")
    else
        return print(buf, "\"", escape_string(val), "\"")
    end
end

function yaml_value!(buf::IOBuffer, f::Function, val::Symbol; kw...)::Nothing
    return yaml_value!(buf, f, string(val); kw...)
end

function yaml_value!(buf::IOBuffer, f::Function, val::TimeType; kw...)::Nothing
    return yaml_value!(buf, f, string(val); kw...)
end

function yaml_value!(buf::IOBuffer, f::Function, val::UUID; kw...)::Nothing
    return yaml_value!(buf, f, string(val); kw...)
end

function yaml_value!(buf::IOBuffer, f::Function, val::AbstractChar; kw...)::Nothing
    return print(buf, "\'", val, "\'")
end

function yaml_value!(buf::IOBuffer, f::Function, val::Bool; kw...)::Nothing
    return print(buf, val)
end

function yaml_value!(buf::IOBuffer, f::Function, val::Number; kw...)::Nothing
    return if isnan(val)
        print(buf, ".nan")
    elseif isinf(val)
        print(buf, ".inf")
    else
        print(buf, val)
    end
end

function yaml_value!(buf::IOBuffer, f::Function, val::Enum; kw...)::Nothing
    return print(buf, val)
end

function yaml_value!(buf::IOBuffer, f::Function, val::Missing; kw...)::Nothing
    return print(buf, YAML_NULL)
end

function yaml_value!(buf::IOBuffer, f::Function, val::Nothing; kw...)::Nothing
    return print(buf, YAML_NULL)
end

function yaml_value!(buf::IOBuffer, f::Function, val::Type; kw...)::Nothing
    return print(buf, val)
end

function yaml_value!(buf::IOBuffer, f::Function, val::Function; kw...)::Nothing
    throw("Can't serialize type 'Function' to YAML data")
end

function yaml_value!(buf::IOBuffer, f::Function, val::Pair; l::Int64, skip_lf::Bool = false, kw...)::Nothing
    print(buf, skip_lf ? "" : indent(l))
    yaml_value!(buf, f, first(val); l = l + 1, is_key = true, kw...)
    print(buf, ": ")
    yaml_value!(buf, f, last(val); l = l + 1, kw...)
    return print(buf)
end

function yaml_value!(buf::IOBuffer, f::Function, val::AbstractDict; l::Int64, skip_lf::Bool = false, kw...)::Nothing
    next = iterate(val)
    print(buf, skip_lf ? "" : indent(l))
    while next !== nothing
        (k, v), index = next
        yaml_value!(buf, f, k; l = l + 1, is_key = true, kw...)
        print(buf, any(map(t -> isa(v, t), INDENT_TYPES)) ? ":" : ": ")
        yaml_value!(buf, f, v; l = l + 1, kw...)
        next = iterate(val, index)
        next === nothing || print(buf, indent(l))
    end
    return print(buf)
end

function yaml_value!(buf::IOBuffer, f::Function, val::AbstractVector; l::Int64, skip_lf::Bool = false, kw...)::Nothing
    next = iterate(val)
    print(buf, skip_lf ? "" : indent(l))
    while next !== nothing
        item, index = next
        print(buf, "- ")
        yaml_value!(buf, f, item; l = l + 1, skip_lf = true, kw...)
        next = iterate(val, index)
        next === nothing || print(buf, indent(l))
    end
    return print(buf)
end

function yaml_value!(buf::IOBuffer, f::Function, val::Tuple; l::Int64, skip_lf::Bool = false, kw...)::Nothing
    next = iterate(val)
    print(buf, skip_lf ? "" : indent(l))
    while next !== nothing
        item, index = next
        print(buf, "- ")
        yaml_value!(buf, f, item; l = l + 1, skip_lf = true, kw...)
        next = iterate(val, index)
        next === nothing || print(buf, indent(l))
    end
    return print(buf)
end

function yaml_value!(buf::IOBuffer, f::Function, val::NamedTuple; l::Int64, skip_lf::Bool = false, kw...)::Nothing
    names = keys(val)
    print(buf, skip_lf ? "" : indent(l))
    next = iterate(names)
    next_value = iterate(val)
    while next !== nothing
        item, index = next
        item_value, index_value = next_value
        yaml_value!(buf, f, item; l = l + 1, is_key = true, kw...)
        print(buf, ": ")
        yaml_value!(buf, f, item_value; l = l + 1, skip_lf = true, kw...)
        next = iterate(names, index)
        next_value = iterate(val, index_value)
        next === nothing || print(buf, indent(l))
    end
    return print(buf)
end

function yaml_value!(buf::IOBuffer, f::Function, val::AbstractSet; l::Int64, skip_lf::Bool = false, kw...)::Nothing
    next = iterate(val)
    print(buf, skip_lf ? "" : indent(l))
    while next !== nothing
        item, index = next
        print(buf, "- ")
        yaml_value!(buf, f, item; l = l + 1, skip_lf = true, kw...)
        next = iterate(val, index)
        next === nothing || print(buf, indent(l))
    end
    return print(buf)
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

function yaml_value!(buf::IOBuffer, f::Function, val::T; l::Int64, skip_lf::Bool = false, kw...)::Nothing where {T}
    next = iterate(f(T))
    print(buf, skip_lf ? "" : indent(l))
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
        (index - ignore_count) == 2 || print(buf, indent(l))
        yaml_value!(buf, f, k; l = l + 1, is_key = true, kw...)
        print(buf, any(map(t -> isa(v, t), INDENT_TYPES)) ? ":" : ": ")
        yaml_value!(buf, f, v; l = l + 1, kw...)
        next = iterate(f(T), index)
    end
    return print(buf)
end

function yaml_value!(buf::IOBuffer, val::T; l::Int64, kw...)::Nothing where {T}
    return yaml_value!(buf, fieldnames, val; l = 0, kw...)
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
    buf = IOBuffer()
    yaml_value!(buf, x...; l = 0, skip_lf = true, kw...)
    print(buf, "\n")
    return String(take!(buf))
end

end
||||||| parent of 644fb38 (YAML: Handle `YAML` in extension)
module SerYaml

export to_yaml

using Dates

const YAML_NULL = "null"
const INDENT = "  "
const INDENT_TYPES = [Pair, AbstractDict, AbstractVector, Tuple, NamedTuple, AbstractSet]

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

indent(l::Int64)::String = "\n" * (INDENT^l)

function yaml_value!(buf::IOBuffer, f::Function, val::AbstractString; is_key::Bool = false, kw...)::Nothing
    if escape_length(val) == ncodeunits(val)
        return is_key ? print(buf, val) : print(buf, "\"", val, "\"")
    else
        return print(buf, "\"", escape_string(val), "\"")
    end
end

function yaml_value!(buf::IOBuffer, f::Function, val::Symbol; kw...)::Nothing
    return yaml_value!(buf, f, string(val); kw...)
end

function yaml_value!(buf::IOBuffer, f::Function, val::TimeType; kw...)::Nothing
    return yaml_value!(buf, f, string(val); kw...)
end

function yaml_value!(buf::IOBuffer, f::Function, val::AbstractChar; kw...)::Nothing
    return print(buf, "\'", val, "\'")
end

function yaml_value!(buf::IOBuffer, f::Function, val::Bool; kw...)::Nothing
    return print(buf, val)
end

function yaml_value!(buf::IOBuffer, f::Function, val::Number; kw...)::Nothing
    return if isnan(val)
        print(buf, ".nan")
    elseif isinf(val)
        print(buf, ".inf")
    else
        print(buf, val)
    end
end

function yaml_value!(buf::IOBuffer, f::Function, val::Enum; kw...)::Nothing
    return print(buf, val)
end

function yaml_value!(buf::IOBuffer, f::Function, val::Missing; kw...)::Nothing
    return print(buf, YAML_NULL)
end

function yaml_value!(buf::IOBuffer, f::Function, val::Nothing; kw...)::Nothing
    return print(buf, YAML_NULL)
end

function yaml_value!(buf::IOBuffer, f::Function, val::Type; kw...)::Nothing
    return print(buf, val)
end

function yaml_value!(buf::IOBuffer, f::Function, val::Function; kw...)::Nothing
    throw("Can't serialize type 'Function' to YAML data")
end

function yaml_value!(buf::IOBuffer, f::Function, val::Pair; l::Int64, skip_lf::Bool = false, kw...)::Nothing
    print(buf, skip_lf ? "" : indent(l))
    yaml_value!(buf, f, first(val); l = l + 1, is_key = true, kw...)
    print(buf, ": ")
    yaml_value!(buf, f, last(val); l = l + 1, kw...)
    return print(buf)
end

function yaml_value!(buf::IOBuffer, f::Function, val::AbstractDict; l::Int64, skip_lf::Bool = false, kw...)::Nothing
    next = iterate(val)
    print(buf, skip_lf ? "" : indent(l))
    while next !== nothing
        (k, v), index = next
        yaml_value!(buf, f, k; l = l + 1, is_key = true, kw...)
        print(buf, any(map(t -> isa(v, t), INDENT_TYPES)) ? ":" : ": ")
        yaml_value!(buf, f, v; l = l + 1, kw...)
        next = iterate(val, index)
        next === nothing || print(buf, indent(l))
    end
    return print(buf)
end

function yaml_value!(buf::IOBuffer, f::Function, val::AbstractVector; l::Int64, skip_lf::Bool = false, kw...)::Nothing
    next = iterate(val)
    print(buf, skip_lf ? "" : indent(l))
    while next !== nothing
        item, index = next
        print(buf, "- ")
        yaml_value!(buf, f, item; l = l + 1, skip_lf = true, kw...)
        next = iterate(val, index)
        next === nothing || print(buf, indent(l))
    end
    return print(buf)
end

function yaml_value!(buf::IOBuffer, f::Function, val::Tuple; l::Int64, skip_lf::Bool = false, kw...)::Nothing
    next = iterate(val)
    print(buf, skip_lf ? "" : indent(l))
    while next !== nothing
        item, index = next
        print(buf, "- ")
        yaml_value!(buf, f, item; l = l + 1, skip_lf = true, kw...)
        next = iterate(val, index)
        next === nothing || print(buf, indent(l))
    end
    return print(buf)
end

function yaml_value!(buf::IOBuffer, f::Function, val::NamedTuple; l::Int64, skip_lf::Bool = false, kw...)::Nothing
    names = keys(val)
    print(buf, skip_lf ? "" : indent(l))
    next = iterate(names)
    next_value = iterate(val)
    while next !== nothing
        item, index = next
        item_value, index_value = next_value
        yaml_value!(buf, f, item; l = l + 1, is_key = true, kw...)
        print(buf, ": ")
        yaml_value!(buf, f, item_value; l = l + 1, skip_lf = true, kw...)
        next = iterate(names, index)
        next_value = iterate(val, index_value)
        next === nothing || print(buf, indent(l))
    end
    return print(buf)
end

function yaml_value!(buf::IOBuffer, f::Function, val::AbstractSet; l::Int64, skip_lf::Bool = false, kw...)::Nothing
    next = iterate(val)
    print(buf, skip_lf ? "" : indent(l))
    while next !== nothing
        item, index = next
        print(buf, "- ")
        yaml_value!(buf, f, item; l = l + 1, skip_lf = true, kw...)
        next = iterate(val, index)
        next === nothing || print(buf, indent(l))
    end
    return print(buf)
end

(ser_name(::Type{T}, ::Val{x})::Symbol) where {T,x} = x
(ser_value(::Type{T}, ::Val{x}, v::V)::V) where {T,x,V} = v
(ser_type(::Type{T}, v::V)::V) where {T,V} = v

(isnull(::Any)::Bool) = false
(isnull(v::Missing)::Bool) = true
(isnull(v::Nothing)::Bool) = true
(isnull(v::Float64)::Bool) = isnan(v) || isinf(v)

(ignore_null(::Type{T})::Bool) where {T} = false

(ignore_field(::Type{T}, ::Val{x})::Bool) where {T,x} = false
(ignore_field(::Type{T}, k::Val{x}, v::V)::Bool) where {T,x,V} = ignore_field(T, k)

function yaml_value!(buf::IOBuffer, f::Function, val::T; l::Int64, skip_lf::Bool = false, kw...)::Nothing where {T}
    next = iterate(f(T))
    print(buf, skip_lf ? "" : indent(l))
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
        (index - ignore_count) == 2 || print(buf, indent(l))
        yaml_value!(buf, f, k; l = l + 1, is_key = true, kw...)
        print(buf, any(map(t -> isa(v, t), INDENT_TYPES)) ? ":" : ": ")
        yaml_value!(buf, f, v; l = l + 1, kw...)
        next = iterate(f(T), index)
    end
    return print(buf)
end

function yaml_value!(buf::IOBuffer, val::T; l::Int64, kw...)::Nothing where {T}
    return yaml_value!(buf, fieldnames, val; l = 0, kw...)
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
    buf = IOBuffer()
    yaml_value!(buf, x...; l = 0, skip_lf = true, kw...)
    print(buf, "\n")
    return String(take!(buf))
end

end
