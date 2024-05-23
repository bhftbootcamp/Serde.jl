# Serde.jl Changelog

The latest version of this file can be found at the master branch of the [Serde.jl](https://bhftbootcamp.github.io/Serde.jl) repository.

## 3.0.4 (21/05/2024)
- Supports deserialization of Union{Nulltype,AnyType} type

## 3.0.0 (22/03/2024)

### Added

- Macro `@serde_pascal_case` to transform field names from PascalCase to snake_case for deserialization ([#26](../../pull/26)).
- Macro `@serde_camel_case` to transform field names from camelCase to snake_case for deserialization ([#26](../../pull/26)).
- Macro `@serde_kebab_case` to transform field names from kebab-case to snake_case for deserialization ([#26](../../pull/26)).
- `Serde.ser_name` to override the default field name serialization ([#26](../../pull/26)).
- `Serde.ser_value` to override the default value serialization ([#26](../../pull/26)).
- `Serde.ser_type` to override the default type serialization ([#26](../../pull/26)).
- `Serde.ser_ignore_field` to determine if a field should be ignored during serialization ([#26](../../pull/26)).

### Changed

- Renamed macro `@ser_json_name` to `@ser_name` for consistency with other serialization macros ([#26](../../pull/26)).
- Renamed `ignore_null` to `ser_ignore_null` to align with serialization function naming conventions ([#26](../../pull/26)).
- Renamed `ignore_field` to `ser_ignore_field` for clarity in serialization customization ([#26](../../pull/26)).

## 2.0.0 (22/02/2024)

### Added

- Function `Serde.deser_xml` for deserializing XML ([#14](../../pull/14)).
- Function `Serde.parse_xml` for parsing XML ([#14](../../pull/14)).
- Function `Serde.to_yaml` for converting to YAML ([#14](../../pull/14)).
- Function `Serde.parse_yaml` for parsing YAML ([#14](../../pull/14)).
- Function `Serde.deser_yaml` for deserializing YAML ([#14](../../pull/14)).
- Parameter `with_names` in `to_csv` to toggle the inclusion or exclusion of headers in CSV output ([#17](../../pull/17)).

### Changed

- Refactored tests to improve maintainability and performance.
