"""
    Serde.issimple(value) -> Bool

Returns `true` if `value` is a scalar type that should be serialized inline (as a
leaf node) rather than as a nested structure.

Format backends use this predicate to decide whether a value should be written as a
plain scalar or as a nested object/array. Users rarely need to call this directly;
it is primarily a hook for format implementors.

Types that return `true`: `AbstractString`, `Symbol`, `AbstractChar`, `Number`,
`Enum`, `Type`, `Dates.TimeType`, `UUID`. All other types return `false`.

See also: [`Serde.isnull`](@ref).
"""
issimple(::Any)::Bool             = false
issimple(::AbstractString)::Bool  = true
issimple(::Symbol)::Bool          = true
issimple(::AbstractChar)::Bool    = true
issimple(::Number)::Bool          = true
issimple(::Enum)::Bool            = true
issimple(::Type)::Bool            = true
issimple(::Dates.TimeType)::Bool  = true
issimple(::UUID)::Bool            = true

"""
    Serde.isnull(value) -> Bool

Returns `true` if `value` represents the absence of data during serialization.

Format backends use this to determine whether a field should be omitted or written as
a null/nil marker. Only `nothing` and `missing` are considered null by default.

# Examples
```jldoctest
julia> Serde.isnull(nothing)
true

julia> Serde.isnull(missing)
true

julia> Serde.isnull(0)
false

julia> Serde.isnull("")
false
```

See also: [`Serde.ser_skip`](@ref), [`Serde.issimple`](@ref).
"""
isnull(::Any)::Bool     = false
isnull(::Missing)::Bool = true
isnull(::Nothing)::Bool = true

"""
    Serde.ser_pairs(val::T) -> Vector{Tuple{Symbol, Any}}
    Serde.ser_pairs(strategy, val::T) -> Vector{Tuple{Symbol, Any}}

Returns a vector of `(name, value)` pairs for all non-skipped fields of `val`.

The pairs are produced by applying [`Serde.ser_skip`](@ref), [`Serde.ser_name`](@ref),
[`Serde.ser_value`](@ref), and [`Serde.ser_type`](@ref) hooks in order.
Pass a context object `strategy` as the first argument to apply context-aware trait overrides
(e.g. [`CamelCase`](@ref) key renaming).

Format backends should use `ser_pairs` rather than iterating `fieldnames` directly, so
that all serialization hooks are respected.

# Arguments
- `val::T`: the value to serialize.
- `strategy`: optional context object (e.g. `CamelCase()`, `PascalCase()`).

# Returns
`Vector{Tuple{Symbol, Any}}` — ordered list of `(output_key, transformed_value)` pairs.

# Examples
```julia
julia> struct Point; x::Int; y::Int; end

julia> Serde.ser_pairs(Point(1, 2))
2-element Vector{Tuple{Symbol, Any}}:
 (:x, 1)
 (:y, 2)

julia> Serde.ser_skip(::Type{Point}, ::Val{:y}) = true

julia> Serde.ser_pairs(Point(1, 2))
1-element Vector{Tuple{Symbol, Any}}:
 (:x, 1)
```

See also: [`Serde.ser_name`](@ref), [`Serde.ser_value`](@ref), [`Serde.ser_type`](@ref),
[`Serde.ser_skip`](@ref).
"""
function ser_pairs(val::T) where {T}
    pairs = Tuple{Symbol,Any}[]
    for field in fieldnames(T)
        v = ser_type(T, ser_value(T, Val(field), getfield(val, field)))
        ser_skip(T, Val(field), v) && continue
        k = ser_name(T, Val(field))
        push!(pairs, (k, v))
    end
    return pairs
end

function ser_pairs(strategy, val::T) where {T}
    pairs = Tuple{Symbol,Any}[]
    for field in fieldnames(T)
        v = ser_type(strategy, T, ser_value(strategy, T, Val(field), getfield(val, field)))
        ser_skip(strategy, T, Val(field), v) && continue
        k = ser_name(strategy, T, Val(field))
        push!(pairs, (k, v))
    end
    return pairs
end

"""
    Serde.to_flatten(data; delimiter = "_") -> Dict{String, Any}

Flattens a nested dictionary or struct into a single-level `Dict{String,Any}`.

Keys at each nesting level are concatenated with `delimiter`. Nested dicts and nested
structs (types whose `ClassType` is `StructClass`) are both expanded recursively; scalar
values are left as-is.

# Arguments
- `data`: a nested `AbstractDict` or any struct value.

# Keyword arguments
- `delimiter::AbstractString = "_"`: separator inserted between parent and child key names.
- `dict_type::Type{<:AbstractDict} = Dict{String,Any}`: the concrete dict type to use for the result.

# Returns
A flat `dict_type` with all keys joined by `delimiter`.

# Examples
```julia
julia> nested = Dict("a" => 1, "b" => Dict("c" => 2, "d" => Dict("e" => 3)));

julia> Serde.to_flatten(nested)
Dict{String, Any} with 3 entries:
  "a"     => 1
  "b_c"   => 2
  "b_d_e" => 3

julia> struct Address; city::String; zip::String; end

julia> struct Person; name::String; address::Address; end

julia> Serde.to_flatten(Person("Alice", Address("NY", "10001")))
Dict{String, Any} with 3 entries:
  "name"         => "Alice"
  "address_city" => "NY"
  "address_zip"  => "10001"
```

See also: [`Serde.ser_pairs`](@ref).
"""
function to_flatten(
    data::AbstractDict{K,V};
    delimiter::AbstractString = "_",
    dict_type::Type{<:AbstractDict} = Dict{String,Any},
) where {K,V}
    result = dict_type()
    for (key, value) in data
        if isa(value, AbstractDict)
            for (k, v) in to_flatten(value; delimiter, dict_type)
                result[string(key) * delimiter * k] = v
            end
        else
            result[string(key)] = value
        end
    end
    return result
end

function to_flatten(
    data::T;
    delimiter::AbstractString = "_",
    dict_type::Type{<:AbstractDict} = Dict{String,Any},
) where {T}
    result = dict_type()
    for key in fieldnames(T)
        value = getfield(data, key)
        if value isa AbstractDict || (!issimple(value) && ClassType(value) isa StructClass)
            for (k, v) in to_flatten(value; delimiter, dict_type)
                result[string(key) * delimiter * k] = v
            end
        else
            result[string(key)] = value
        end
    end
    return result
end
