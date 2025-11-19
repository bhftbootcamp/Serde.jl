module ParToml

export parse_toml

using TOML
using ..Strategy
import ..DeserSyntaxError
import ..TomlParsingStrategy
import ..default_toml_strategy

"""
    parse_toml(x::AbstractString; strategy::TomlParsingStrategy) -> Dict{String,Any}
    parse_toml(x::Vector{UInt8}; strategy::TomlParsingStrategy) -> Dict{String,Any}

Parses a TOML string `x` (or vector of UInt8) into a dictionary using the provided parsing strategy.

## Arguments
- `x`: TOML string or vector of UInt8
- `strategy`: Parsing strategy (defaults to TOML.jl based strategy)

## Examples

```julia-repl
julia> toml = \"\"\"
       tag = "line"
       [[points]]
       x = 1
       y = 0
       \"\"\";

julia> parse_toml(toml)
Dict{String, Any} with 2 entries:
  "tag"  => "line"
  "points" => Any[Dict{String, Any}("y"=>0, "x"=>1)]
```
"""
function parse_toml end

function parse_toml(x::AbstractString; strategy::TomlParsingStrategy = default_toml_strategy(), kw...)
    return strategy.parser(x; kw...)
end

function parse_toml(x::Vector{UInt8}; strategy::TomlParsingStrategy = default_toml_strategy(), kw...)
    return parse_toml(unsafe_string(pointer(x), length(x)); strategy = strategy, kw...)
end

end
