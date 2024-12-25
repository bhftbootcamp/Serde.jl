# [Extended serialization](@id ex_ser)

Serde.jl users have the flexibility to customize the serialization process of their data.

## [Changing output names](@id ser_name)

If you want to change the output names of your custom type, you just have to extend the `Serde.<SubModule>.ser_name` function.
This approach is supported by the following serialization methods:

- [`to_json`](@ref) (`SerJson` submodule).
- [`to_toml`](@ref) (`SerToml` submodule).
- [`to_query`](@ref) (`SerQuery` submodule).
- [`to_xml`](@ref) (`SerXml` submodule).
- [`to_yaml`](@ref) (`SerYaml` submodule).

The return value of your method must be of type `Symbol` or `String`.
The default signature is:

```julia
ser_name(::Type{T}, ::Val{x})::Symbol where {T,x} = x
```

### Example

For convenience, we import the necessary `SerJson` submodule.

```julia
using Serde.SerJson
```

Then, let's define a simple custom type `Ticket`.

```julia
struct Ticket
    cost::Int64
end
```

Now, we can add a new method `SerJson.ser_name` for the custom type `Ticket` and its field `cost`.

```julia
SerJson.ser_name(::Type{Ticket}, ::Val{:cost}) = :price
```

After that, in the resulting JSON string the field `cost` will become `price`.

```julia-repl
julia> to_json(Ticket(1000)) |> print
{"price":1000}
```

## Handling field values

Also, we can specify how to process certain fields of custom types.
In that case, you need extend the `Serde.<SubModule>.ser_value` function.
This approach is supported by such serialization methods:

- [`to_json`](@ref) (`SerJson` submodule).
- [`to_toml`](@ref) (`SerToml` submodule).
- [`to_query`](@ref) (`SerQuery` submodule).
- [`to_xml`](@ref) (`SerXml` submodule).
- [`to_yaml`](@ref) (`SerYaml` submodule).

The method can return a value of any type.
The default signature is:

```julia
ser_value(::Type{T}, ::Val{x}, v::V) where {T,x,V} = v
```

### Example

For convenience, we import the necessary `SerJson` submodule.

```julia
using Dates
using Serde.SerJson
```

Then, let's define a simple custom type `Calendar`.

```julia
struct JuliaBirthday
    date::DateTime
end
```

In the next line, we add a method `SerJson.ser_value` for the custom type `JuliaBirthday` and its field `date` of type `DateTime`.

```julia
function SerJson.ser_value(::Type{JuliaBirthday}, ::Val{:date}, v::DateTime)
    return Dates.value(Nanosecond(datetime2unix(v)))
end
```

Now, we will obtain a nanosecond value of the field `v`.

```julia-repl
julia> to_json(JuliaBirthday(DateTime(2012, 2, 14))) |> print
{"date":1329177600}
```

## Handling values of specific types

If you want to override how to serialize a specific type, you need extend the `Serde.<SubModule>.ser_type` function.
This approach is supported by the following serialization methods:

- [`to_json`](@ref) (`SerJson` submodule).
- [`to_toml`](@ref) (`SerToml` submodule).
- [`to_query`](@ref) (`SerQuery` submodule).
- [`to_xml`](@ref) (`SerXml` submodule).
- [`to_yaml`](@ref) (`SerYaml` submodule).

The method can return a value of any type.
The default signature is:

```julia
ser_type(::Type{T}, v::V) where {T,V} = v
```

### Example

For convenience, we import the necessary `SerJson` submodule.

```julia
using Serde.SerJson
```

Then, let's define a simple custom type `Computer` with two string fields.

```julia
struct Computer
    cpu::String
    gpu::String
end
```

As well, we can add a method `SerJson.ser_type` for type `Computer` and all its fields of type `String`.

```julia
SerJson.ser_type(::Type{Computer}, v::String) = uppercase(v)
```

Now, every string field of `Computer` will be in uppercase.

```julia-repl
julia> to_json(Computer("i7-12900", "rtx-4090")) |> print
{"cpu":"I7-12900","gpu":"RTX-4090"}
```

## Ignoring fields

Finally, we can specify what fields must be ignored.
In this case, you just need to extend the `Serde.<SubModule>.ser_ignore_field` function.
This approach is supported by the following serialization methods:

- [`to_json`](@ref) (`SerJson` submodule).

The return value of your method must be of type `Bool`.
The default signature is:

```julia
ser_ignore_field(::Type{T}, ::Val{x})::Bool where {T,x} = false
```

### Example

For convenience, we import the necessary submodule.

```julia
using Serde.SerJson
```

Then, let's define a simple custom type `Box`.

```julia
struct Box
    height::Int64
    width::Int64
    length::Int64
end
```

Let's add the `SerJson.ser_ignore_field` method for type `Box`.

```julia
SerJson.ser_ignore_field(::Type{Box}, ::Val{:length}) = true
```

Because the field `length` is ignorable, the resulting JSON string contains only `height` and `width` values.

```
to_json(Box(2, 5, 6)) |> print
{"height":2,"width":5}
```
