module Strategy

using JSON
using .....Serde: AbstractParsingStrategy, DeserSyntaxError

export JsonParsingStrategy, default_json_strategy

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

end
