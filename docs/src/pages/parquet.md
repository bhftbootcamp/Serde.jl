# Parquet

Parquet support is provided by a package extension. It activates automatically
once `Parquet2` is loaded:

```julia
import Pkg; Pkg.add("Parquet2")
import Parquet2    # activates SerdeParquetExt
```

## Parsing

```@docs
Serde.parse_parquet
```

## Deserialization

```@docs
from_parquet
try_from_parquet
```

## Serialization

```@docs
to_parquet
```
