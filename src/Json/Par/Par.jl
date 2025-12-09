module JsonPar

export parse_json, JsonParsingStrategy, default_json_strategy

using JSON
using .....Serde: AbstractParsingStrategy, DeserSyntaxError

struct JsonParsingStrategy <: AbstractParsingStrategy
    parser::Function
end

function default_json_strategy()
    JsonParsingStrategy((x; kw...) -> begin
        try
            JSON.parse(x; kw...)
        catch e
            throw(DeserSyntaxError("json", "failed to parse JSON input", e))
        end
    end)
end

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
