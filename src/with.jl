
"""
    With(strategies...) -> With

Compose multiple serialization/deserialization strategies into a single strategy.

`With` delegates every trait call to its component strategies using a
well-defined combination rule per trait:

| Trait | Rule |
|---|---|
| `ser_name` / `deser_name` | first-wins: use the first strategy that renames the field |
| `ser_skip` | OR: skip if any strategy says skip |
| `ser_value` / `ser_type` / `deser_transform` | chain: apply each strategy in order |
| `has_default` | OR: field has a default if any strategy provides one |
| `deser_default` | first-wins: use the first strategy that has a default |
| `isempty_value` | OR: treat as empty if any strategy says so |
| `deser_validate` | all: run every strategy's validator |

# Examples
```julia
julia> struct Order
           order_id::Int
           total_amount::Float64
       end

julia> to_json(With(CamelCase()), Order(1, 99.9))
"{\"orderId\":1,\"totalAmount\":99.9}"

julia> from_json(With(CamelCase()), Order, "{\"orderId\":1,\"totalAmount\":99.9}")
Order(1, 99.9)
```

See also: [`CamelCase`](@ref), [`PascalCase`](@ref), [`KebabCase`](@ref).
"""
struct With{Ctxs<:Tuple}
    ctxs::Ctxs
end

With(args...) = With(args)

# ── ser_name: first-wins ──────────────────────────────────────────────────────

_with_ser_name(::Tuple{}, ::Type{T}, ::Val{x}) where {T,x} = x
function _with_ser_name(ctxs::Tuple, ::Type{T}, ::Val{x}) where {T,x}
    v = ser_name(first(ctxs), T, Val(x))
    return v === x ? _with_ser_name(Base.tail(ctxs), T, Val(x)) : v
end

ser_name(w::With, ::Type{T}, ::Val{x}) where {T,x} = _with_ser_name(w.ctxs, T, Val(x))

# ── deser_name: first-wins ────────────────────────────────────────────────────

_with_deser_name(::Tuple{}, ::Type{T}, ::Val{x}) where {T,x} = x
function _with_deser_name(ctxs::Tuple, ::Type{T}, ::Val{x}) where {T,x}
    v = deser_name(first(ctxs), T, Val(x))
    return v === x ? _with_deser_name(Base.tail(ctxs), T, Val(x)) : v
end

deser_name(w::With, ::Type{T}, ::Val{x}) where {T,x} = _with_deser_name(w.ctxs, T, Val(x))

# ── ser_skip: OR ──────────────────────────────────────────────────────────────

_with_ser_skip(::Tuple{}, ::Type{T}, ::Val{x}) where {T,x} = false
function _with_ser_skip(ctxs::Tuple, ::Type{T}, ::Val{x}) where {T,x}
    ser_skip(first(ctxs), T, Val(x)) && return true
    return _with_ser_skip(Base.tail(ctxs), T, Val(x))
end

_with_ser_skip_v(::Tuple{}, ::Type{T}, ::Val{x}, v) where {T,x} = false
function _with_ser_skip_v(ctxs::Tuple, ::Type{T}, ::Val{x}, v) where {T,x}
    ser_skip(first(ctxs), T, Val(x), v) && return true
    return _with_ser_skip_v(Base.tail(ctxs), T, Val(x), v)
end

ser_skip(w::With, ::Type{T}, ::Val{x}) where {T,x}    = _with_ser_skip(w.ctxs, T, Val(x))
ser_skip(w::With, ::Type{T}, ::Val{x}, v) where {T,x} = _with_ser_skip_v(w.ctxs, T, Val(x), v)

# ── ser_value: chain ──────────────────────────────────────────────────────────

_with_ser_value(::Tuple{}, ::Type{T}, ::Val{x}, v) where {T,x} = v
function _with_ser_value(ctxs::Tuple, ::Type{T}, ::Val{x}, v) where {T,x}
    return _with_ser_value(Base.tail(ctxs), T, Val(x), ser_value(first(ctxs), T, Val(x), v))
end

ser_value(w::With, ::Type{T}, ::Val{x}, v) where {T,x} = _with_ser_value(w.ctxs, T, Val(x), v)

# ── ser_type: chain ───────────────────────────────────────────────────────────

_with_ser_type(::Tuple{}, ::Type{T}, v) where {T} = v
function _with_ser_type(ctxs::Tuple, ::Type{T}, v) where {T}
    return _with_ser_type(Base.tail(ctxs), T, ser_type(first(ctxs), T, v))
end

ser_type(w::With, ::Type{T}, v) where {T} = _with_ser_type(w.ctxs, T, v)

# ── has_default: OR ───────────────────────────────────────────────────────────

_with_has_default(::Tuple{}, ::Type{T}, ::Val{x}) where {T,x} = false
function _with_has_default(ctxs::Tuple, ::Type{T}, ::Val{x}) where {T,x}
    has_default(first(ctxs), T, Val(x)) && return true
    return _with_has_default(Base.tail(ctxs), T, Val(x))
end

has_default(w::With, ::Type{T}, ::Val{x}) where {T,x} = _with_has_default(w.ctxs, T, Val(x))

# ── deser_default: first-wins ─────────────────────────────────────────────────

_with_deser_default(::Tuple{}, ::Type{T}, ::Val{x}) where {T,x} = nothing
function _with_deser_default(ctxs::Tuple, ::Type{T}, ::Val{x}) where {T,x}
    s = first(ctxs)
    has_default(s, T, Val(x)) && return deser_default(s, T, Val(x))
    return _with_deser_default(Base.tail(ctxs), T, Val(x))
end

deser_default(w::With, ::Type{T}, ::Val{x}) where {T,x} = _with_deser_default(w.ctxs, T, Val(x))

# ── isempty_value: OR ─────────────────────────────────────────────────────────

_with_isempty_value(::Tuple{}, ::Type{T}, ::Val{x}, v) where {T,x} = false
function _with_isempty_value(ctxs::Tuple, ::Type{T}, ::Val{x}, v) where {T,x}
    isempty_value(first(ctxs), T, Val(x), v) && return true
    return _with_isempty_value(Base.tail(ctxs), T, Val(x), v)
end

isempty_value(w::With, ::Type{T}, ::Val{x}, v) where {T,x} = _with_isempty_value(w.ctxs, T, Val(x), v)

# ── deser_transform: chain ────────────────────────────────────────────────────

_with_deser_transform(::Tuple{}, ::Type{T}, ::Type{F}, v) where {T,F} = v
function _with_deser_transform(ctxs::Tuple, ::Type{T}, ::Type{F}, v) where {T,F}
    return _with_deser_transform(Base.tail(ctxs), T, F, deser_transform(first(ctxs), T, F, v))
end

deser_transform(w::With, ::Type{T}, ::Type{F}, v) where {T,F} = _with_deser_transform(w.ctxs, T, F, v)

# ── deser_validate: all ───────────────────────────────────────────────────────

_with_deser_validate(::Tuple{}, ::Type{T}, ::Val{x}, v) where {T,x} = nothing
function _with_deser_validate(ctxs::Tuple, ::Type{T}, ::Val{x}, v) where {T,x}
    deser_validate(first(ctxs), T, Val(x), v)
    return _with_deser_validate(Base.tail(ctxs), T, Val(x), v)
end

deser_validate(w::With, ::Type{T}, ::Val{x}, v) where {T,x} = _with_deser_validate(w.ctxs, T, Val(x), v)
