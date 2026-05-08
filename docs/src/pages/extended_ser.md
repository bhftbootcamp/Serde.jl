# Extended serialization

Serde.jl lets you customise how your types are serialized by overriding a small set of
trait functions.  All traits are dispatched on the concrete type being serialized,
optionally combined with a strategy object.

## Renaming output fields

```@docs
Serde.ser_name
```

## Transforming field values

```@docs
Serde.ser_value
```

## Transforming values by type

```@docs
Serde.ser_type
```

## Skipping fields

```@docs
Serde.ser_skip(::Type, ::Val)
Serde.ser_skip(::Type, ::Val, ::Any)
```
