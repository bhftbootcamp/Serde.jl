# Extended deserialization

Serde.jl lets you customise how data is mapped onto your types by overriding a small set of
trait functions.

## Core deserialization hook

```@docs
Serde.deser
```

## Renaming input keys

```@docs
Serde.deser_name
```

## Default values

```@docs
Serde.has_default
Serde.deser_default
```

## Null handling

```@docs
Serde.nulltype
Serde.isempty_value
```

## Value transformation

```@docs
Serde.deser_transform
```

## Validation

```@docs
Serde.deser_validate
```
