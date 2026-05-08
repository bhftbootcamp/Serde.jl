# Serde.jl

Serde is a Julia library for (de)serializing data to/from various formats. Inspired by [serde.rs](https://serde.rs/), it provides a strategy-based API for customizing serialization behaviour without boilerplate. Supported formats:

```@raw html
<html>
  <body>
    <table>
      <tr><th>Format</th><th><div align=center>JSON</div></th><th><div align=center>TOML</div></th><th><div align=center>XML</div></th><th><div align=center>YAML</div></th><th><div align=center>CSV</div></th><th><div align=center>Query</div></th><th><div align=center>MsgPack</div></th><th><div align=center>BSON</div></th></tr>
      <tr>
        <td>Deserialization</td>
        <td><div align=center>✓</div></td>
        <td><div align=center>✓</div></td>
        <td><div align=center>✓</div></td>
        <td><div align=center>✓</div></td>
        <td><div align=center>✓</div></td>
        <td><div align=center>✓</div></td>
        <td><div align=center>✓</div></td>
        <td><div align=center>✓</div></td>
      </tr>
      <tr>
        <td>Serialization</td>
        <td><div align=center>✓</div></td>
        <td><div align=center>✓</div></td>
        <td><div align=center>✓</div></td>
        <td><div align=center>✓</div></td>
        <td><div align=center>✓</div></td>
        <td><div align=center>✓</div></td>
        <td><div align=center>✓</div></td>
        <td><div align=center>✓</div></td>
      </tr>
    </table>
  </body>
</html>
```

## Installation

```julia
] add Serde
```

## Usage

### Deserialization

```julia
using Dates, Serde

struct JuliaCon
    title::String
    start_date::Date
    end_date::Date
end

function Serde.deser(::Type{JuliaCon}, ::Type{Date}, v::String)
    return Dates.Date(v, "U d, yyyy")
end

json = """{"title":"JuliaCon 2024","start_date":"July 9, 2024","end_date":"July 13, 2024"}"""

julia> from_json(JuliaCon, json)
JuliaCon("JuliaCon 2024", Date("2024-07-09"), Date("2024-07-13"))
```

The same struct works across all formats:

```julia
toml = """
title = "JuliaCon 2024"
start_date = "July 9, 2024"
end_date = "July 13, 2024"
"""

julia> from_toml(JuliaCon, toml)
JuliaCon("JuliaCon 2024", Date("2024-07-09"), Date("2024-07-13"))

query = "title=JuliaCon 2024&start_date=July 9, 2024&end_date=July 13, 2024"

julia> from_query(JuliaCon, query)
JuliaCon("JuliaCon 2024", Date("2024-07-09"), Date("2024-07-13"))

csv = """
title,start_date,end_date
"JuliaCon 2024","July 9, 2024","July 13, 2024"
"""

julia> from_csv(JuliaCon, csv)
1-element Vector{JuliaCon}:
 JuliaCon("JuliaCon 2024", Date("2024-07-09"), Date("2024-07-13"))
```

If you want to see more deserialization options, take a look at the corresponding [section](pages/extended_de.md) of the documentation.

### Serialization

```julia
using Dates, Serde

struct JuliaCon
    title::String
    start_date::Date
    end_date::Date
end

Serde.ser_type(::Type{JuliaCon}, v::Date) = Dates.format(v, "U d, yyyy")

juliacon = JuliaCon("JuliaCon 2024", Date(2024, 7, 9), Date(2024, 7, 13))

julia> to_json(juliacon) |> print
{"title":"JuliaCon 2024","start_date":"July 9, 2024","end_date":"July 13, 2024"}

julia> to_toml(juliacon) |> print
title = "JuliaCon 2024"
start_date = "July 9, 2024"
end_date = "July 13, 2024"
```

If you want to see more serialization options, take a look at the corresponding [section](pages/extended_ser.md) of the documentation.

### Strategies

Strategies rename fields globally without touching the struct definition:

```julia
struct Order
    order_id::Int
    total_amount::Float64
end

julia> to_json(CamelCase(), Order(1, 99.9))
"{\"orderId\":1,\"totalAmount\":99.9}"

julia> from_json(CamelCase(), Order, "{\"orderId\":1,\"totalAmount\":99.9}")
Order(1, 99.9)
```

Combine multiple strategies with `With`:

```julia
struct MyCtx end

Serde.has_default(::MyCtx, ::Type{Order}, ::Val{:total_amount}) = true
Serde.deser_default(::MyCtx, ::Type{Order}, ::Val{:total_amount}) = 0.0

julia> from_json(With(CamelCase(), MyCtx()), Order, "{\"orderId\":5}")
Order(5, 0.0)
```
