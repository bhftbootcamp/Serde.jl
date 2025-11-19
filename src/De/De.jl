# De/De



struct FormatRegistry
    strategies::Dict{Symbol, AbstractParsingStrategy}
    special_handling::Dict{Symbol, NamedTuple}
end

const FORMAT_REGISTRY = FormatRegistry(
    Dict{Symbol, AbstractParsingStrategy}(),
    Dict{Symbol, NamedTuple}()
)

function register_format!(registry::FormatRegistry, format::Symbol, strategy::AbstractParsingStrategy;
                         vector_result::Bool = false, extra_kwargs::NamedTuple = NamedTuple())
    registry.strategies[format] = strategy
    if vector_result || !isempty(extra_kwargs)
        registry.special_handling[format] = (; vector_result, extra_kwargs)
    end
end

function get_strategy(registry::FormatRegistry, format::Symbol)
    get(registry.strategies, format) do
        throw(ArgumentError("Unknown format: $format"))
    end
end

function get_special_handling(registry::FormatRegistry, format::Symbol)
    get(registry.special_handling, format, (; vector_result = false, extra_kwargs = NamedTuple()))
end

include("Deser.jl")

"""
    Serde.to_deser(::Type{T}, x) -> T

Creates a new object of type `T` with values corresponding to the key-value pairs of the dictionary `x`.

## Examples
```julia-repl
julia> struct Info
           id::Int64
           salary::Int64
       end

julia> struct Person
           name::String
           age::Int64
           info::Info
       end

julia> info_data = Dict("id" => 12, "salary" => 2500);

julia> person_data = Dict("name" => "Michael", "age" => 25, "info" => info_data);

julia> Serde.to_deser(Person, person_data)
Person("Michael", 25, Info(12, 2500))
```
"""
to_deser(::Type{T}, x) where {T} = deser(T, x)

to_deser(::Type{Nothing}, x) = nothing
to_deser(::Type{Missing}, x) = missing

include("DeJson.jl")
using .DeJson

include("DeToml.jl")
using .DeToml

include("DeQuery.jl")
using .DeQuery

include("DeCsv.jl")
using .DeCsv

include("DeXml.jl")
using .DeXml

include("DeJson.jl")
register_format!(FORMAT_REGISTRY, :json, default_json_strategy())

include("DeToml.jl")
register_format!(FORMAT_REGISTRY, :toml, default_toml_strategy())

include("DeQuery.jl")
register_format!(FORMAT_REGISTRY, :query, default_query_strategy())

include("DeCsv.jl")
register_format!(FORMAT_REGISTRY, :csv, default_csv_strategy(), vector_result = true)

include("DeXml.jl")
register_format!(FORMAT_REGISTRY, :xml, default_xml_strategy())

include("DeYaml.jl")
register_format!(FORMAT_REGISTRY, :yaml, default_yaml_strategy())

using ..Strategy

function deser(::Type{T}, parser::Strategy.AbstractParserStrategy, x; kw...) where {T}
    return to_deser(T, Strategy.parse(parser, x; kw...))
end

function deser(f::Function, parser::Strategy.AbstractParserStrategy, x; kw...)
    object = Strategy.parse(parser, x; kw...)
    return to_deser(f(object), object)
end
