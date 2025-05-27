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
issimple(::TimeType)::Bool = true

rec_valtype(x::T) where {T} = rec_valtype(T)
rec_valtype(::Type{<:Any}) = Any
rec_valtype(::Type{<:AbstractDict{<:Any,V}}) where {V} = V
rec_valtype(::Type{<:AbstractDict{<:Any,V}}) where {V<:AbstractDict} = rec_valtype(V)

"""
    to_flatten([dict_type=Dict{String,Any}], data; delimiter = '_') -> dict_type

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

julia> to_flatten(nested_dict; delimiter = "__")
Dict{String, Any} with 3 entries:
  "bar__foo"      => 2
  "bar__baz__foo" => 3
  "foo"           => 1

julia> to_flatten(Dict{String,Int}, nested_dict; delimiter = "__")
Dict{String, Int64} with 3 entries:
  "bar__foo"      => 2
  "bar__baz__foo" => 3
  "foo"           => 1
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

julia> to_flatten(nested_struct)
Dict{String, Any} with 3 entries:
  "str"     => "a"
  "bar_num" => 1.0
  "val"     => 1
```
"""
function to_flatten(
    ::Type{D},
    data::AbstractDict;
    delimiter::Union{AbstractChar,AbstractString} = '_',
) where {V,D<:AbstractDict{String,V}}
    result = D()
    for (key, value) in data
        if value isa AbstractDict
            for (k, v) in to_flatten(Dict{String,V}, value; delimiter)
                result[string(key) * delimiter * k] = v
            end
        else
            result[string(key)] = value
        end
    end
    return result
end

function to_flatten(
    ::Type{D},
    data::T;
    delimiter::Union{AbstractChar,AbstractString} = '_',
) where {T,V,D<:AbstractDict{String,V}}
    result = D()
    for key in fieldnames(T)
        value = getproperty(data, key)
        if !issimple(value)
            for (k, v) in to_flatten(Dict{String,V}, value; delimiter)
                result[string(key) * delimiter * k] = v
            end
        else
            result[string(key)] = value
        end
    end
    return result
end

# kwarg dict_type for backward compatibility
function to_flatten(
    data::Any;
    dict_type::Type{D} = Dict{String,rec_valtype(data)},
    delimiter::Union{AbstractChar,AbstractString} = '_',
) where {D<:AbstractDict{String}}
    return to_flatten(D, data; delimiter)
end
