# Serde.jl Examples

This directory contains example code demonstrating how to use Serde.jl for serialization and deserialization.

## Available Examples

### `parquet_example.jl`

Demonstrates Parquet file serialization and deserialization with:

- **Example 1**: Simple Struct Serialization
  - Serialize simple Julia structs to Parquet
  - Parse and deserialize Parquet data

- **Example 2**: Working with Complex Structs
  - Serialize custom Julia structs to Parquet
  - Deserialize Parquet data back to typed structs

- **Example 3**: Working with Larger Datasets
  - Handle datasets with many records efficiently
  - Verify data integrity after write/read cycle

- **Example 4**: Type Conversion During Deserialization
  - Automatic type conversion (e.g., Int64 → Float64)
  - Demonstrates Serde.jl's flexible type handling

## Running the Examples

To run an example, use:

```bash
julia --project=. examples/parquet_example.jl
```

Or from the Julia REPL:

```julia
julia> using Pkg

julia> Pkg.activate(".")

julia> include("examples/parquet_example.jl")
```

## Additional Format Examples

For examples of other supported formats (JSON, YAML, XML, TOML, CSV, Query), please refer to the [main documentation](../README.md).

## Creating Your Own Examples

When creating examples for Serde.jl:

1. Keep examples focused on a single concept
2. Include comments explaining each step
3. Clean up temporary files after use
4. Show both serialization and deserialization
5. Demonstrate error handling where appropriate

## Need Help?

- Check the [README](../README.md) for comprehensive documentation
- Visit the [GitHub repository](https://github.com/bhftbootcamp/Serde.jl) for issues and discussions
- See the [test files](../test/) for more usage examples
