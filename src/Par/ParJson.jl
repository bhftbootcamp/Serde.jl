module ParJson

export parse_json

using JSON
using ..Strategy
import ..DeserSyntaxError
import ..JsonParsingStrategy
import ..default_json_strategy

"""
    parse_json(x::AbstractString; strategy::JsonParsingStrategy, kw...) -> Dict{String,Any}
    parse_json(x::Vector{UInt8}; strategy::JsonParsingStrategy, kw...) -> Dict{String,Any}

Parse a JSON string `x` (or vector of UInt8) into a dictionary using the provided parsing strategy.

## Arguments
- `x`: JSON string or vector of UInt8
- `strategy`: Parsing strategy (defaults to JSON.jl based strategy)

## Examples

```julia-repl
julia> json = \"\"\"
        {
            "number": 123,
            "vector": [1, 2, 3]
        }
       \"\"\";

julia> parse_json(json)
Dict{String, Any} with 2 entries:
  "number" => 123
  "vector" => Any[1, 2, 3]
```
"""
function parse_json end

function parse_json(x::AbstractString; strategy::JsonParsingStrategy = default_json_strategy(), kw...)
    return strategy.parser(x; kw...)
end

function parse_json(x::Vector{UInt8}; strategy::JsonParsingStrategy = default_json_strategy(), kw...)
    return parse_json(unsafe_string(pointer(x), length(x)); strategy = strategy, kw...)
end

end
