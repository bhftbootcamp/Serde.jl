# Strategies

Strategies control field naming and other serialization/deserialization behaviour globally.
Pass a strategy as the first argument to any `from_*` or `to_*` function.

## Built-in strategies

```@docs
CamelCase
PascalCase
KebabCase
LowerCase
```

## Composing strategies

```@docs
With
```

## Default strategy

```@docs
Serde.DefaultStrategy
```
