# [Extended deserialization](@id ex_deser)

Serde.jl allows users to define how their custom data will be processed during deserialization.

```@docs
Serde.deser(::Type, ::Any)
```

## Custom deserialization behavior

If you need to deserialize non-standard custom data types, it will be useful to define a behavior to handle them.

```@docs
Serde.deser(::Type, ::Type, ::Any)
```

## Empty values handling

We can also determine which data types and their values will be treated as `nothing`.

```@docs
Serde.isempty
```

## Names aliases

Sometimes, the field names of the incoming data structure differ from their intended destination.
In this case, it is convenient to specify name aliases.

```@docs
Serde.custom_name
```

## Custom default values

We can also define default values for certain data types.

```@docs
Serde.default_value
```

## Null types handling

We can also determine the 'nulltype' for custom types when they are empty or not specified at all.

```@docs
Serde.nulltype
```

## Ignore fields

Finally, we can specify which fields should be ignored during deserialization.

```@docs
Serde.isignored_name
```