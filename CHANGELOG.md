# Serde.jl Changelog

The latest version of this file can be found at the master branch of the [Serde.jl repository](https://bhftbootcamp.github.io/Serde.jl).

## 2.0.0 (22/02/2024)

### Added

- Function `Serde.deser_xml` for deserializing XML (#14).
- Function `Serde.parse_xml` for parsing XML (#14).
- Function `Serde.to_yaml` for converting to YAML (#14).
- Function `Serde.parse_yaml` for parsing YAML (#14).
- Function `Serde.deser_yaml` for deserializing YAML (#14).
- Parameter `with_names` to `to_csv` function to toggle inclusion of headers in CSV output (#17).

### Changed

- Refactored tests to improve maintainability and performance.
