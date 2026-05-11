"""
    Serde.deser(::Type{T}, data) -> T
    Serde.deser(strategy, ::Type{T}, data) -> T

Construct an object of type `T` from already-parsed `data` (a `Dict`, `Vector`, or scalar).

This is the core deserialization primitive. Format-specific functions (`from_json`,
`from_yaml`, etc.) first parse raw bytes into Julia data structures, then delegate to
`deser` to map those structures onto the target type.

The deserialization pipeline for each field of a struct:
1. Look up the key via [`Serde.deser_name`](@ref).
2. If absent, fall back to [`Serde.deser_default`](@ref) or [`Serde.nulltype`](@ref).
3. Apply [`Serde.isempty_value`](@ref) / [`Serde.deser_transform`](@ref).
4. Convert to the field type.
5. Run [`Serde.deser_validate`](@ref).

Pass a context object `strategy` as the first argument to apply context-aware trait overrides
(such as field renaming via [`CamelCase`](@ref)).

# Arguments
- `::Type{T}`: target type to construct.
- `data`: parsed input — typically a `Dict{String,Any}`, `Vector{Any}`, or a scalar.
- `strategy`: optional context object (e.g. `CamelCase()`, `PascalCase()`).

# Returns
A fully constructed value of type `T`.

# Throws
- [`MissingFieldError`](@ref): a required field is absent and has no default.
- [`TypeMismatchError`](@ref): a field value cannot be converted to the declared type.
- [`ValidationError`](@ref): a field fails a custom `deser_validate` check.

# Examples
```julia
julia> struct Point; x::Int; y::Int; end

julia> Serde.deser(Point, Dict("x" => 1, "y" => 2))
Point(1, 2)

julia> Serde.deser(Point, Dict("x" => "3", "y" => "4"))  # string → int coercion
Point(3, 4)

julia> Serde.deser(CamelCase(), Point, Dict("x" => 1, "y" => 2))
Point(1, 2)
```

See also: [`Serde.to_deser`](@ref), [`from_json`](@ref), [`Serde.deser_name`](@ref).
"""
deser(::Type, ::Any)

"""
    Serde.deser(strategy, ::Type{T}, ::Type{FieldType}, data) -> FieldType

Field-level deserialization hook. Called by the engine when converting `data` to the
type declared for a particular field.

Override this method to implement custom type conversions that cannot be handled by
[`Serde.deser_transform`](@ref). The first type parameter `T` is the enclosing struct;
the second is the field's declared type.

# Examples
```julia
using Dates

struct LogEntry
    timestamp::DateTime
    message::String
end

# Accept Unix timestamps (integers) as DateTime
function Serde.deser(strategy, ::Type{LogEntry}, ::Type{DateTime}, x::Integer)
    return Dates.unix2datetime(x / 1000)
end
```

See also: [`Serde.deser`](@ref), [`Serde.deser_transform`](@ref).
"""
deser(::Any, ::Type, ::Type, ::Any)

# ── Entry points ──────────────────────────────────────────────────────────────

deser(::Type{T}, data) where {T} = deser(DefaultStrategy(), ClassType(T), T, data)
deser(strategy, ::Type{T}, data) where {T} = deser(strategy, ClassType(T), T, data)

# ── PrimitiveClass ────────────────────────────────────────────────────────────

deser(strategy, ::PrimitiveClass, ::Type{T}, data::T) where {T} = data
deser(strategy, ::PrimitiveClass, ::Type{T}, data::AbstractString) where {T<:Symbol} = Symbol(data)
deser(strategy, ::PrimitiveClass, ::Type{T}, data::AbstractString) where {T<:Number} = tryparse(T, data)
deser(strategy, ::PrimitiveClass, ::Type{T}, data::Number) where {T<:Number} = T(data)
deser(strategy, ::PrimitiveClass, ::Type{T}, data::Integer) where {T<:AbstractFloat} = data
deser(strategy, ::PrimitiveClass, ::Type{T}, data::AbstractString) where {T<:AbstractString} = T(data)
deser(strategy, ::PrimitiveClass, ::Type{T}, data::Symbol) where {T<:AbstractString} = string(data)
deser(strategy, ::PrimitiveClass, ::Type{T}, data::Number) where {T<:AbstractString} = string(data)
deser(strategy, ::PrimitiveClass, ::Type{T}, data::Integer) where {T<:Enum} = T(data)

function deser(strategy, ::PrimitiveClass, ::Type{T}, data::AbstractString) where {T<:Enum}
    return deser(strategy, PrimitiveClass(), T, Symbol(data))
end

function deser(strategy, ::PrimitiveClass, ::Type{T}, data::Symbol) where {T<:Enum}
    for (index, name) in Base.Enums.namemap(T)
        name === data && return T(index)
    end
    return nothing
end

# ── NullClass ─────────────────────────────────────────────────────────────────

deser(strategy, ::NullClass, ::Type{Nothing}, ::Nothing) = nothing
deser(strategy, ::NullClass, ::Type{Missing}, ::Nothing) = missing

# ── Union types ───────────────────────────────────────────────────────────────

deser(::Type{Union{Nothing,T}}, data) where {T} = deser(DefaultStrategy(), T, data)
deser(strategy, ::Type{Union{Nothing,T}}, data) where {T} = deser(strategy, T, data)

deser(::Type{Union{Missing,T}}, data) where {T} = deser(DefaultStrategy(), T, data)
deser(strategy, ::Type{Union{Missing,T}}, data) where {T} = deser(strategy, T, data)

deser(::Type{Nothing}, ::Nothing) = nothing
deser(::Type{Missing}, ::Missing) = missing

deser(::Type{Nothing}, ::Any) = throw(MethodError(deser, (Nothing, nothing)))
deser(::Type{Missing}, ::Any) = throw(MethodError(deser, (Missing, missing)))

# ── Field-type dispatch ───────────────────────────────────────────────────────

deser(strategy, ::Type{T}, ::Type{Union{Nothing,E}}, data) where {T,E} = deser(strategy, E, data)
deser(strategy, ::Type{T}, ::Type{E}, data) where {T,E} = deser(strategy, E, data)
deser(strategy, ::Type{T}, ::Type{Nothing}, data) where {T} = deser(Nothing, data)

# ── NTupleClass ───────────────────────────────────────────────────────────────

function deser(strategy, ::NTupleClass, ::Type{T}, data::AbstractDict{K,D}) where {T<:NamedTuple,K,D}
    target = Dict{Symbol,D}()
    for (k, v) in data
        target[Symbol(k)] = v
    end
    return (; target...)
end

# ── VectorClass ───────────────────────────────────────────────────────────────

function deser(strategy, ::VectorClass, ::Type{T}, data::AbstractVector) where {T<:AbstractVector}
    return map(x -> deser(strategy, eltype(T), x), data)
end

function deser(strategy, ::VectorClass, ::Type{T}, data::Union{Tuple,AbstractVector}) where {T<:Tuple}
    if T === Tuple || isa(T, UnionAll)
        return T(data)
    else
        return T(deser(strategy, t, v) for (t, v) in zip(fieldtypes(T), data))
    end
end

function deser(strategy, ::VectorClass, ::Type{T}, data::AbstractArray) where {T<:AbstractSet}
    return T(data)
end

# ── DictClass ─────────────────────────────────────────────────────────────────

function deser(strategy, ::DictClass, ::Type{T}, data::AbstractDict{K,D}) where {T<:AbstractDict,K,D}
    target = T()
    for (k, v) in data
        try
            target[deser(keytype(target), k)] = deser(strategy, valtype(target), v)
        catch e
            if e isa MethodError
                throw(TypeMismatchError(T, Symbol(k), valtype(target), typeof(v), v))
            else
                rethrow(e)
            end
        end
    end
    return target
end

# ── Helper functions (strategy first) ──────────────────────────────────────────────

@inline function _field_convert(strategy, ct::Type, ft::Type, field::Symbol, data)
    isnothing(data) && !(nothing isa ft) && throw(MissingFieldError(ct, field))
    try
        return data isa ft ? data : deser(strategy, ct, ft, data)
    catch e
        if e isa MethodError || e isa ArgumentError || e isa InexactError
            throw(TypeMismatchError(ct, field, ft, typeof(data), data))
        else
            rethrow(e)
        end
    end
end

@inline function _field_default(strategy, ::Type{T}, field::Symbol, ::Type{F}) where {T,F}
    has_default(strategy, T, Val(field)) && return deser_default(strategy, T, Val(field))
    return nulltype(F)
end

@inline function _field_normalize(strategy, ::Type{T}, field::Symbol, ::Type{F}, val) where {T,F}
    if isnothing(val) || ismissing(val) || isempty_value(strategy, T, Val(field), val)
        return nulltype(F)
    end
    return deser_transform(strategy, T, F, val)
end

@inline function _field_validate(strategy, ::Type{T}, field::Symbol, val) where {T}
    deser_validate(strategy, T, Val(field), val)
    return val
end

# ── StructClass ───────────────────────────────────────────────────────────────

function deser(strategy, ::StructClass, ::Type{T}, data::AbstractVector) where {T}
    N = fieldcount(T)
    constructor = (args...) -> T(args...)
    Base.@nexprs 32 i -> begin
        if i <= N
            F_i = fieldtype(T, i)
            name_i = fieldnames(T)[i]
            val_i = get(data, i, _field_default(strategy, T, name_i, F_i))
            val_i = _field_normalize(strategy, T, name_i, F_i, val_i)
            x_i = _field_validate(strategy, T, name_i, _field_convert(strategy, T, F_i, name_i, val_i))
            N == i && return Base.@ncall i constructor x
        end
    end
    others = Any[]
    for i in 33:N
        F_i = fieldtype(T, i)
        name_i = fieldnames(T)[i]
        val_i = get(data, i, _field_default(strategy, T, name_i, F_i))
        val_i = _field_normalize(strategy, T, name_i, F_i, val_i)
        push!(others, _field_validate(strategy, T, name_i, _field_convert(strategy, T, F_i, name_i, val_i)))
    end
    return constructor(
        x_1, x_2, x_3, x_4, x_5, x_6, x_7, x_8, x_9, x_10, x_11, x_12, x_13,
        x_14, x_15, x_16, x_17, x_18, x_19, x_20, x_21, x_22, x_23, x_24, x_25,
        x_26, x_27, x_28, x_29, x_30, x_31, x_32, others...,
    )
end

function deser(strategy, ::StructClass, ::Type{T}, data::AbstractDict{K,D}) where {T,K<:Union{AbstractString,Symbol},D}
    N = fieldcount(T)
    constructor = (args...) -> T(args...)
    Base.@nexprs 32 i -> begin
        if i <= N
            F_i = fieldtype(T, i)
            name_i = fieldnames(T)[i]
            key_i = deser_name(strategy, T, Val(name_i))
            key_i = isa(key_i, K) ? key_i : deser(K, key_i)
            val_i = get(data, key_i, _field_default(strategy, T, name_i, F_i))
            val_i = _field_normalize(strategy, T, name_i, F_i, val_i)
            x_i = _field_validate(strategy, T, name_i, _field_convert(strategy, T, F_i, name_i, val_i))
            N == i && return Base.@ncall i constructor x
        end
    end
    others = Any[]
    for i in 33:N
        F_i = fieldtype(T, i)
        name_i = fieldnames(T)[i]
        key_i = deser_name(strategy, T, Val(name_i))
        key_i = isa(key_i, K) ? key_i : deser(K, key_i)
        val_i = get(data, key_i, _field_default(strategy, T, name_i, F_i))
        val_i = _field_normalize(strategy, T, name_i, F_i, val_i)
        push!(others, _field_validate(strategy, T, name_i, _field_convert(strategy, T, F_i, name_i, val_i)))
    end
    return constructor(
        x_1, x_2, x_3, x_4, x_5, x_6, x_7, x_8, x_9, x_10, x_11, x_12, x_13,
        x_14, x_15, x_16, x_17, x_18, x_19, x_20, x_21, x_22, x_23, x_24, x_25,
        x_26, x_27, x_28, x_29, x_30, x_31, x_32, others...,
    )
end

function deser(strategy, ::TaggedClass, ::Type{T}, data::AbstractDict{K,D}) where {T,K<:Union{AbstractString,Symbol},D}
    tk = tag_key(strategy, T)
    tag_val = get(data, isa(tk, K) ? tk : deser(K, tk), nothing)
    if tag_val !== nothing
        for (tv, ST) in tag_subtypes(strategy, T)
            string(tag_val) == string(tv) && return deser(strategy, ST, data)
        end
    end
    throw(TypeMismatchError(T, Symbol(tk), T, typeof(tag_val), tag_val))
end

function deser(strategy, ::StructClass, ::Type{T}, data::NamedTuple) where {T}
    N = fieldcount(T)
    constructor = (args...) -> T(args...)
    Base.@nexprs 32 i -> begin
        if i <= N
            F_i = fieldtype(T, i)
            name_i = fieldnames(T)[i]
            key_i = Symbol(deser_name(strategy, T, Val(name_i)))
            val_i = get(data, key_i, _field_default(strategy, T, name_i, F_i))
            val_i = _field_normalize(strategy, T, name_i, F_i, val_i)
            x_i = _field_validate(strategy, T, name_i, _field_convert(strategy, T, F_i, name_i, val_i))
            N == i && return Base.@ncall i constructor x
        end
    end
    others = Any[]
    for i in 33:N
        F_i = fieldtype(T, i)
        name_i = fieldnames(T)[i]
        key_i = Symbol(deser_name(strategy, T, Val(name_i)))
        val_i = get(data, key_i, _field_default(strategy, T, name_i, F_i))
        val_i = _field_normalize(strategy, T, name_i, F_i, val_i)
        push!(others, _field_validate(strategy, T, name_i, _field_convert(strategy, T, F_i, name_i, val_i)))
    end
    return constructor(
        x_1, x_2, x_3, x_4, x_5, x_6, x_7, x_8, x_9, x_10, x_11, x_12, x_13,
        x_14, x_15, x_16, x_17, x_18, x_19, x_20, x_21, x_22, x_23, x_24, x_25,
        x_26, x_27, x_28, x_29, x_30, x_31, x_32, others...,
    )
end

# ── to_deser / parse_value ────────────────────────────────────────────────────

"""
    Serde.to_deser(::Type{T}, x) -> T
    Serde.to_deser(strategy, ::Type{T}, x) -> T

Alias for [`Serde.deser`](@ref). Used internally by format backends as the standard entry
point after parsing. Prefer `deser` in application code.

Special cases: `to_deser(Nothing, x)` always returns `nothing`; `to_deser(Missing, x)`
always returns `missing`.

See also: [`Serde.deser`](@ref).
"""
to_deser(::Type{T}, x) where {T} = deser(T, x)
to_deser(strategy, ::Type{T}, x) where {T} = deser(strategy, T, x)
to_deser(::Type{Nothing}, x) = nothing
to_deser(::Type{Missing}, x) = missing

"""
    Serde.parse_value(::Type{ST}, ::Type{FT}, value)

Extensible value parsing hook used by the query-string format backend.

Before a query-string value is deserialized into a field of type `FT` in struct `ST`,
this function is called to pre-process the raw string (or string vector for repeated keys).

The default implementation returns `value` unchanged. Override to handle custom
coercions for specific struct/field type combinations in query strings.

See also: [`from_query`](@ref), [`parse_query`](@ref).
"""
parse_value(::Type, ::Type, value) = value
