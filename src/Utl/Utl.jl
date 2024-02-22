# Utl/Utl

using Dates

include("Macros.jl")

issimple(::Any)::Bool = false
issimple(::AbstractString)::Bool = true
issimple(::Symbol)::Bool = true
issimple(::AbstractChar)::Bool = true
issimple(::Number)::Bool = true
issimple(::Enum)::Bool = true
issimple(::Type)::Bool = true
issimple(::Dates.TimeType)::Bool = true

"""
    Serde.to_flatten(data; delimiter = "_") -> Dict{String, Any}

Transforms a nested dictionary `data` (or custom type) into a single-level dictionary. The keys in the new dictionary are created by joining the nested keys (or fieldnames) with `delimiter` symbol.

## Examples

Flatten the nested dictionary with custom `delimiter` symbol.

```julia-repl
julia> nested_dict = Dict(
       "foo" => 1,
       "bar" => Dict(
           "foo" => 2,
           "baz" => Dict(
              "foo" => 3,
               ),
           ),
       );

julia> Serde.to_flatten(nested_dict; delimiter = "__")
Dict{String, Any} with 3 entries:
  :bar__baz__foo => 3
  :foo           => 1
  :bar__foo      => 2
```

Flatten the nested structure.

```julia-repl
julia> struct Bar
           num::Float64
       end

julia> struct Foo
           val::Int64
           str::String
           bar::Bar
       end

julia> nested_struct = Foo(1, "a", Bar(1.0));

julia> Serde.to_flatten(nested_struct)
Dict{String, Any} with 3 entries:
  :bar_num => 1.0
  :val   => 1
  :str   => "a"
```
"""
function to_flatten(
    data::AbstractDict{K,V};
    delimiter::AbstractString = "_",
)::Dict{String,Any} where {K,V}
    result = Dict{String,Any}()
    for (key, value) in data
        key = string(key)
        if isa(value, AbstractDict)
            for (k, v) in to_flatten(value; delimiter = delimiter)
                result[key * delimiter * k] = v
            end
        else
            result[key] = value
        end
    end
    return result
end

function to_flatten(data::T; delimiter::AbstractString = "_")::Dict{String,Any} where {T}
    result = Dict{String,Any}()
    for key in fieldnames(T)
        value = getproperty(data, key)
        key = string(key)
        if !issimple(value)
            for (k, v) in to_flatten(value; delimiter = delimiter)
                result[key * delimiter * k] = v
            end
        else
            result[key] = value
        end
    end
    return result
end
