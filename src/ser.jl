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
    Serde.iter_fields(callback, val)
    Serde.iter_fields(callback, strategy, val)

Iterate over the serializable fields of `val`, applying the full trait
pipeline ([`Serde.ser_value`](@ref), [`Serde.ser_type`](@ref),
[`Serde.ser_skip`](@ref), [`Serde.ser_name`](@ref)) to each. `callback` is
invoked as `callback(name::Symbol, value)` for every non-skipped field, with
`name` the transformed key and `value` the transformed value.

The callback's return value is ignored.

# Examples
```julia
struct User; user_id::Int; name::String; end

# Collect (key, value) pairs through CamelCase renaming.
out = Tuple{Symbol,Any}[]
Serde.iter_fields(CamelCase(), User(1, "Ada")) do k, v
    push!(out, (k, v))
end
# out == [(:userId, 1), (:name, "Ada")]
```

See also: [`Serde.ser_pairs`](@ref).
"""
function iter_fields end

function iter_fields(callback::F, strategy, val::T) where {F,T}
    ct = ClassType(T)
    (ct isa StructClass || ct isa NTupleClass || ct isa TaggedClass) ||
        throw(ArgumentError(
            "iter_fields: $T (ClassType $(ct)) is not a struct or NamedTuple"))
    N = fieldcount(T)
    N == 0 && return nothing
    Base.@nexprs 32 i -> begin
        if i <= N
            fn_i = fieldname(T, i)
            v_i = ser_type(strategy, T, ser_value(strategy, T, Val(fn_i), getfield(val, fn_i)))
            if !ser_skip(strategy, T, Val(fn_i), v_i)
                k_i = ser_name(strategy, T, Val(fn_i))
                callback(k_i isa Symbol ? k_i : Symbol(k_i), v_i)
            end
        end
    end
    if N > 32
        for fn in fieldnames(T)[33:end]
            v = ser_type(strategy, T, ser_value(strategy, T, Val(fn), getfield(val, fn)))
            ser_skip(strategy, T, Val(fn), v) && continue
            k = ser_name(strategy, T, Val(fn))
            callback(k isa Symbol ? k : Symbol(k), v)
        end
    end
    return nothing
end

iter_fields(callback::F, val) where {F} = iter_fields(callback, DefaultStrategy(), val)

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
