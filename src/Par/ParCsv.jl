module ParCsv

export parse_csv

using CSV
using ..Strategy
import ..DeserSyntaxError
import ..CsvParsingStrategy
import ..default_csv_strategy

"""
    parse_csv(x::AbstractString; strategy::CsvParsingStrategy, kw...) -> Vector{NamedTuple}
    parse_csv(x::Vector{UInt8}; strategy::CsvParsingStrategy, kw...) -> Vector{NamedTuple}

Parse a CSV string `x` (or vector of UInt8) into a vector of named tuples using the provided parsing strategy.

## Arguments
- `x`: CSV string or vector of UInt8
- `strategy`: Parsing strategy (defaults to CSV.jl based strategy)

## Examples

```julia-repl
julia> csv = \"\"\"
       "id","name","grade"
       1,"Fred",78.2
       2,"Benny",82.0
       \"\"\";

julia> parse_csv(csv)
2-element Vector{NamedTuple{(:id, :name, :grade), Tuple{String, String, String}}}:
 (id = "1", name = "Fred", grade = "78.2")
 (id = "2", name = "Benny", grade = "82.0")
```
"""
function parse_csv end

function parse_csv(x::AbstractString; strategy::CsvParsingStrategy = default_csv_strategy(), delimiter::AbstractString = ",", kw...)
    io = IOBuffer(x)
    try
        return strategy.parser(io; delim = delimiter, kw...)
    finally
        close(io)
    end
end

function parse_csv(x::Vector{UInt8}; strategy::CsvParsingStrategy = default_csv_strategy(), delimiter::AbstractString = ",", kw...)
    return parse_csv(unsafe_string(pointer(x), length(x)); strategy = strategy, delimiter = delimiter, kw...)
end

end
