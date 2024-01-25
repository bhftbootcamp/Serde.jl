# Serde.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://bhftbootcamp.github.io/Serde.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://bhftbootcamp.github.io/Serde.jl/dev/)
[![Build Status](https://github.com/bhftbootcamp/Serde.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/bhftbootcamp/Serde.jl/actions/workflows/CI.yml?query=branch%3Amaster)
[![Coverage](https://codecov.io/gh/bhftbootcamp/Serde.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/bhftbootcamp/Serde.jl)

Serde is a Julia library for (de)serializing data to/from various formats. The library offers a simple and concise API for defining custom (de)serialization behavior for user-defined types. Inspired by the [serde.rs](https://serde.rs/) Rust library, it supports the following data formats:

<html>
  <body>
    <table>
      <tr><th>Format</th><th><div align=center>JSON</div></th><th><div align=center>TOML</div></th><th><div align=center>XML</div></th><th><div align=center>YAML</div></th><th><div align=center>CSV</div></th><th><div align=center>Query</div></th></tr>
      <tr>
        <td>Deserialization</td>
        <td><div align=center>✓</div></td>
        <td><div align=center>✓</div></td>
        <td><div align=center>(planned)</div></td>
        <td><div align=center>(planned)</div></td>
        <td><div align=center>✓</div></td>
        <td><div align=center>✓</div></td>
      </tr>
      <tr>
        <td>Serialization</td>
        <td><div align=center>✓</div></td>
        <td><div align=center>✓</div></td>
        <td><div align=center>✓</div></td>
        <td><div align=center>(planned)</div></td>
        <td><div align=center>✓</div></td>
        <td><div align=center>✓</div></td>
      </tr>
    </table>
  </body>
</html>

## Installation
To install Serde, simply use the Julia package manager:

```julia
] add Serde
```

## Usage

Let's look at some of the most used cases

### Deserialization

The following is an example of how you can deserialize various formats, like JSON, TOML, Query and CSV into a custom structure `JuliaCon`.
The deserialization process was also modified to correctly process `start_date` and `end_date` by adding the method `Serde.deser`

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
julia> juliacon = deser_json(JuliaCon, json)
 JuliaCon("JuliaCon 2024", Date("2024-07-09"), Date("2024-07-13"))

# TOML deserialization example
toml = """
title = "JuliaCon 2024"
start_date = "July 9, 2024"
end_date = "July 13, 2024"
"""

# Deserialize TOML to a JuliaCon object
julia> juliacon = deser_toml(JuliaCon, toml)
 JuliaCon("JuliaCon 2024", Date("2024-07-09"), Date("2024-07-13"))

# URL query string deserialization example
query = "title=JuliaCon 2024&start_date=July 9, 2024&end_date=July 13, 2024"

# Deserialize query string to a JuliaCon object
julia> juliacon = deser_query(JuliaCon, query)
 JuliaCon("JuliaCon 2024", Date("2024-07-09"), Date("2024-07-13"))

# CSV deserialization example
csv = """
title,start_date,end_date
"JuliaCon 2024","July 9, 2024","July 13, 2024"
"""

# Deserialize CSV to a vector of JuliaCon objects
julia> juliacon = deser_csv(JuliaCon, csv)
 1-element Vector{JuliaCon}:
  JuliaCon("JuliaCon 2024", Date("2024-07-09"), Date("2024-07-13"))
```

If you want to see more deserialization options, then take a look at the corresponding [section](https://bhftbootcamp.github.io/Serde.jl/stable/pages/extended_de/) of the documentation

### Serialization

The following example shows how an object `juliacon` of custom type `JuliaCon` can be serialized into various formats, like JSON, TOML, XML, etc.
In that case, all dates will be correctly converted into strings of the required format by overloaded function `ser_type`

```julia
using Dates, Serde

# Define the struct to hold the JuliaCon conference details
struct JuliaCon
    title::String
    start_date::Date
    end_date::Date
end

# Create an instance of JuliaCon with the specified details
juliacon = JuliaCon("JuliaCon 2024", Date(2024, 7, 9), Date(2024, 7, 13))

# Define serialization for JuliaCon struct to JSON format
function Serde.SerJson.ser_type(::Type{JuliaCon}, v::Date)
    return Dates.format(v, "U d, yyyy")
end

# Serialize the JuliaCon instance to JSON and print it
julia> to_json(juliacon) |> print
 {"title":"JuliaCon 2024","start_date":"July 9, 2024","end_date":"July 13, 2024"}

# Define serialization for JuliaCon struct to TOML format
function Serde.SerToml.ser_type(::Type{JuliaCon}, v::Date)
    return Dates.format(v, "yyyy-mm-dd")
end

# Serialize the JuliaCon instance to TOML and print it
julia> to_toml(juliacon) |> print
 title = "JuliaCon 2024"
 start_date = "2024-07-09"
 end_date = "2024-07-13"

# Define serialization for JuliaCon struct to XML format
function Serde.SerXml.ser_type(::Type{JuliaCon}, v::Date)
    return Dates.format(v, "yyyy-mm-dd")
end

# Serialize the JuliaCon instance to XML and print it
julia> to_xml(juliacon) |> print
 <xml title="JuliaCon 2024" start_date="2024-07-09" end_date="2024-07-13"/>
```

If you want to see more serialization options, then take a look at the corresponding [section](https://bhftbootcamp.github.io/Serde.jl/stable/pages/extended_ser/) of the documentation

### User friendly (de)serialization

That's not all, work is currently underway on macro functionality that allows for more fine-grained and simpler customization of the (de)serialization process.
You can choose from various available decorators that will allow you to unleash all the possibilities of Serde.
More information can be found in the [documentation](https://bhftbootcamp.github.io/Serde.jl/stable/pages/utils/#Serde.@serde)

```julia
using Dates, Serde

@serde @default_value @de_name struct JuliaCon
    title::String    | "JuliaCon 2024"   | "title"
    start_date::Date | nothing           | "start"
    end_date::Date   | Date(2024, 7, 24) | "end"
end

# Custom deserialization function for the JuliaCon struct
function Serde.deser(::Type{JuliaCon}, ::Type{Date}, v::String)
    return Dates.Date(v)
end

# Deserialization from JSON example
json = """{"title": "JuliaCon 2024", "start": "2024-07-22"}"""

julia> juliacon = deser_json(JuliaCon, json)
 JuliaCon("JuliaCon 2024", Date("2024-07-22"), Date("2024-07-24"))

julia> to_json(juliacon)
 "{\"title\":\"JuliaCon 2024\",\"start_date\":\"2024-07-22\",\"end_date\":\"2024-07-24\"}"
```

## Contributing
Contributions to Serde are welcome! If you encounter a bug, have a feature request, or would like to contribute code, please open an issue or a pull request on GitHub.
