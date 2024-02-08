# Serde.jl

Serde is a Julia library for (de)serializing data to/from various formats. The library offers a simple and concise API for defining custom (de)serialization behavior for user-defined types.  It supports the following data formats:

|     Format      | JSON | TOML |    XML    |    YAML   | CSV | Query |
|-----------------|------|------|-----------|-----------|-----|-------|
| Deserialization |   ✓  |   ✓  | (planned) |     ✓     |  ✓  |   ✓   |
| Serialization   |   ✓  |   ✓  |     ✓     | (planned) |  ✓  |   ✓   |

## Quickstart

Here is how we can use Serde to deserialize JSON to a custom data type and then serialize it to TOML and XML.

```julia
using Dates, Serde

# Define a struct to hold JuliaCon information
struct JuliaCon
    title::String
    start_date::Date
    end_date::Date
end

# Custom deserialization function for the JuliaCon struct
function Serde.deser(::Type{JuliaCon}, ::Type{Date}, v::String)
    return Dates.Date(v, "U d, yyyy")
end 

# JSON deserialization example
json = """
{
  "title": "JuliaCon 2024",
  "start_date": "July 9, 2024",
  "end_date": "July 13, 2024"
}
"""

# Deserialize JSON to a JuliaCon object
juliacon = deser_json(JuliaCon, json)

function Serde.SerToml.ser_type(::Type{JuliaCon}, v::Date)
    return Dates.format(v, "yyyy-mm-dd")
end

# Serialize the JuliaCon instance to TOML and print it
to_toml(juliacon) |> print

# Define serialization for JuliaCon struct to XML format
function Serde.SerXml.ser_type(::Type{JuliaCon}, v::Date)
    return Dates.format(v, "yyyy-mm-dd")
end

# Serialize the JuliaCon instance to XML and print it
to_xml(juliacon) |> print
```
