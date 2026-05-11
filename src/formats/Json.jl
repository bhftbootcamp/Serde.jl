module SerdeJson

using Dates
using UUIDs
using YYJSON

export parse_json, from_json, try_from_json, to_json, to_pretty_json

import ..ParseError, ..SerdeError, ..to_deser
import ..ser_name, ..ser_value, ..ser_type, ..ser_skip
import ..deser_name, ..has_default, ..deser_default
import ..nulltype, ..isempty_value, ..deser_transform, ..deser_validate
import ..ClassType, ..StructClass, ..TaggedClass
import .._field_default, .._field_normalize, .._field_convert, .._field_validate
import ..deser, ..tag_key, ..tag_subtypes
import ..DefaultStrategy

# ═══════════════════════════════════════════════════════════════════════════════
# Parsing: yyjson C parser → Dict{String,Any}
# ═══════════════════════════════════════════════════════════════════════════════

@inline function _yy_read(json::AbstractString)
    err = YYJSONReadErr()
    doc = yyjson_read_opts(json, ncodeunits(json), YYJSON_READ_NOFLAG, YYJSONAlc_NULL, pointer_from_objref(err))
    doc === YYJSONDoc_NULL && throw(ParseError("JSON", "invalid JSON syntax", err))
    return doc
end

@inline function _yy_read(json::Vector{UInt8})
    err = YYJSONReadErr()
    doc = yyjson_read_opts(json, length(json), YYJSON_READ_NOFLAG, YYJSONAlc_NULL, pointer_from_objref(err))
    doc === YYJSONDoc_NULL && throw(ParseError("JSON", "invalid JSON syntax", err))
    return doc
end

function _yy_to_julia(v::Ptr{YYJSONVal})
    yyjson_is_str(v)  && return unsafe_string(yyjson_get_str(v))
    yyjson_is_bool(v) && return yyjson_get_bool(v)
    yyjson_is_real(v) && return yyjson_get_real(v)
    yyjson_is_int(v)  && return Int64(yyjson_get_num(v))
    yyjson_is_null(v) && return nothing
    if yyjson_is_arr(v)
        n = yyjson_arr_size(v)
        result = Vector{Any}(undef, n)
        iter = YYJSONArrIter()
        iter_ptr = pointer_from_objref(iter)
        yyjson_arr_iter_init(v, iter_ptr)
        @inbounds for i in 1:n
            result[i] = _yy_to_julia(yyjson_arr_iter_next(iter_ptr))
        end
        return result
    end
    if yyjson_is_obj(v)
        n = yyjson_obj_size(v)
        d = Dict{String,Any}()
        sizehint!(d, n)
        iter = YYJSONObjIter()
        iter_ptr = pointer_from_objref(iter)
        yyjson_obj_iter_init(v, iter_ptr)
        for _ in 1:n
            key_ptr = yyjson_obj_iter_next(iter_ptr)
            val_ptr = yyjson_obj_iter_get_val(key_ptr)
            d[unsafe_string(yyjson_get_str(key_ptr))] = _yy_to_julia(val_ptr)
        end
        return d
    end
    return nothing
end

"""
    parse_json(x::Union{AbstractString, Vector{UInt8}}; dict_type = Dict{String,Any}) -> Any

Parse a JSON string or byte vector into Julia data structures without mapping to a target type.

Returns the raw parsed value: a `Dict{String,Any}` for JSON objects, a `Vector{Any}` for
arrays, or a scalar (`String`, `Int64`, `Float64`, `Bool`, `Nothing`) for primitive values.

# Arguments
- `x`: JSON text as a `String` or `Vector{UInt8}`.

# Keyword arguments
- `dict_type::Type{<:AbstractDict}`: concrete dict type to use for JSON objects (default `Dict{String,Any}`).

# Returns
The parsed Julia value.

# Throws
- [`ParseError`](@ref): if `x` contains malformed JSON.

# Examples
```julia
julia> parse_json("{\"x\":1,\"y\":2}")
Dict{String, Any}("x" => 1, "y" => 2)

julia> parse_json("[1, 2, 3]")
3-element Vector{Any}: [1, 2, 3]

julia> parse_json("42")
42
```

See also: [`from_json`](@ref), [`try_from_json`](@ref).
"""
function parse_json end

function parse_json(x::AbstractString; dict_type::Type{D} = Dict{String,Any}, kw...) where {D<:AbstractDict}
    doc = _yy_read(x)
    try
        root = yyjson_doc_get_root(doc)
        root === YYJSONVal_NULL && return D()
        val = _yy_to_julia(root)
        return val isa AbstractDict ? convert(D, val) : val
    finally
        yyjson_doc_free(doc)
    end
end

function parse_json(x::Vector{UInt8}; kw...)
    return parse_json(unsafe_string(pointer(x), length(x)); kw...)
end

# ═══════════════════════════════════════════════════════════════════════════════
# Direct deserialization: yyjson DOM → struct (no intermediate Dict)
# ═══════════════════════════════════════════════════════════════════════════════

# Type-guided extraction from a yyjson value pointer.
# The first type parameter T is the parent struct (for field-level deser overrides).

@inline function _yy_extract(::Type, ::Type{String}, v::Ptr{YYJSONVal})
    yyjson_is_str(v) && return unsafe_string(yyjson_get_str(v))
    yyjson_is_bool(v) && return yyjson_get_bool(v) ? "true" : "false"
    yyjson_is_null(v) && return ""
    yyjson_is_int(v) && return string(Int64(yyjson_get_sint(v)))
    yyjson_is_real(v) && return string(yyjson_get_real(v))
    return ""
end

@inline function _yy_extract(::Type, ::Type{Bool}, v::Ptr{YYJSONVal})
    yyjson_is_bool(v) && return yyjson_get_bool(v)
    yyjson_is_str(v) && return unsafe_string(yyjson_get_str(v)) == "true"
    yyjson_is_int(v) && return yyjson_get_sint(v) != 0
    return false
end

@inline function _yy_extract(::Type, ::Type{F}, v::Ptr{YYJSONVal}) where {F<:Signed}
    yyjson_is_int(v) && return F(yyjson_get_sint(v))
    yyjson_is_real(v) && return F(yyjson_get_real(v))
    yyjson_is_str(v) && return parse(F, unsafe_string(yyjson_get_str(v)))
    return F(0)
end

@inline function _yy_extract(::Type, ::Type{F}, v::Ptr{YYJSONVal}) where {F<:Unsigned}
    yyjson_is_uint(v) && return F(yyjson_get_uint(v))
    yyjson_is_int(v) && return F(yyjson_get_sint(v))
    yyjson_is_real(v) && return F(yyjson_get_real(v))
    yyjson_is_str(v) && return parse(F, unsafe_string(yyjson_get_str(v)))
    return F(0)
end

@inline function _yy_extract(::Type, ::Type{F}, v::Ptr{YYJSONVal}) where {F<:AbstractFloat}
    yyjson_is_real(v) && return F(yyjson_get_real(v))
    yyjson_is_int(v) && return F(yyjson_get_num(v))
    yyjson_is_str(v) && return parse(F, unsafe_string(yyjson_get_str(v)))
    return F(0)
end

@inline function _yy_extract(::Type, ::Type{F}, v::Ptr{YYJSONVal}) where {F<:AbstractString}
    yyjson_is_str(v) && return F(unsafe_string(yyjson_get_str(v)))
    yyjson_is_int(v) && return F(string(Int64(yyjson_get_sint(v))))
    yyjson_is_real(v) && return F(string(yyjson_get_real(v)))
    yyjson_is_bool(v) && return F(yyjson_get_bool(v) ? "true" : "false")
    return F("")
end

@inline function _yy_extract(::Type, ::Type{Symbol}, v::Ptr{YYJSONVal})
    yyjson_is_str(v) && return Symbol(unsafe_string(yyjson_get_str(v)))
    return Symbol("")
end

# Nullable
@inline function _yy_extract(::Type{T}, ::Type{Union{Nothing,F}}, v::Ptr{YYJSONVal}) where {T,F}
    yyjson_is_null(v) ? nothing : _yy_extract(T, F, v)
end

@inline function _yy_extract(::Type{T}, ::Type{Union{Missing,F}}, v::Ptr{YYJSONVal}) where {T,F}
    yyjson_is_null(v) ? missing : _yy_extract(T, F, v)
end

@inline _yy_extract(::Type, ::Type{Nothing}, ::Ptr{YYJSONVal}) = nothing
@inline _yy_extract(::Type, ::Type{Missing}, ::Ptr{YYJSONVal}) = missing

# Vector
function _yy_extract(::Type{T}, ::Type{F}, v::Ptr{YYJSONVal}) where {T, F<:AbstractVector}
    E = eltype(F)
    n = yyjson_arr_size(v)
    result = Vector{E}(undef, n)
    iter = YYJSONArrIter()
    iter_ptr = pointer_from_objref(iter)
    yyjson_arr_iter_init(v, iter_ptr)
    @inbounds for i in 1:n
        result[i] = _yy_extract(T, E, yyjson_arr_iter_next(iter_ptr))
    end
    return result
end

# Set
function _yy_extract(::Type{T}, ::Type{F}, v::Ptr{YYJSONVal}) where {T, F<:AbstractSet}
    E = eltype(F)
    n = yyjson_arr_size(v)
    result = F()
    iter = YYJSONArrIter()
    iter_ptr = pointer_from_objref(iter)
    yyjson_arr_iter_init(v, iter_ptr)
    for _ in 1:n
        push!(result, _yy_extract(T, E, yyjson_arr_iter_next(iter_ptr)))
    end
    return result
end

# Tuple
function _yy_extract(::Type{T}, ::Type{F}, v::Ptr{YYJSONVal}) where {T, F<:Tuple}
    types = fieldtypes(F)
    n = length(types)
    vals = Any[_yy_extract(T, types[i], yyjson_arr_get(v, i - 1)) for i in 1:n]
    return F(vals)
end

# Dict
function _yy_extract(::Type{T}, ::Type{F}, v::Ptr{YYJSONVal}) where {T, F<:AbstractDict}
    V = valtype(F)
    n = yyjson_obj_size(v)
    d = F()
    sizehint!(d, n)
    iter = YYJSONObjIter()
    iter_ptr = pointer_from_objref(iter)
    yyjson_obj_iter_init(v, iter_ptr)
    for _ in 1:n
        key_ptr = yyjson_obj_iter_next(iter_ptr)
        val_ptr = yyjson_obj_iter_get_val(key_ptr)
        k = unsafe_string(yyjson_get_str(key_ptr))
        d[k] = V === Any ? _yy_to_julia(val_ptr) : _yy_extract(T, V, val_ptr)
    end
    return d
end

# Generic fallback: struct types → recurse; others → extract raw and let deser convert
function _yy_extract(::Type{T}, ::Type{F}, v::Ptr{YYJSONVal}) where {T, F}
    ct = ClassType(F)
    if ct isa StructClass && fieldcount(F) > 0
        return _yy_deser_struct(DefaultStrategy(), F, v)
    end
    return _yy_to_julia(v)
end

function _yy_deser_struct(strategy, ::Type{T}, obj::Ptr{YYJSONVal}) where {T}
    N = fieldcount(T)
    constructor = (args...) -> T(args...)
    Base.@nexprs 32 i -> begin
        if i <= N
            F_i = fieldtype(T, i)
            name_i = fieldnames(T)[i]
            key_i = string(deser_name(strategy, T, Val(name_i)))
            val_ptr_i = yyjson_obj_getn(obj, key_i, sizeof(key_i))
            if val_ptr_i == YYJSONVal_NULL
                raw_i = _field_default(strategy, T, name_i, F_i)
            elseif yyjson_is_null(val_ptr_i)
                raw_i = nothing
            else
                raw_i = _yy_extract(strategy, T, F_i, val_ptr_i)
            end
            raw_i = _field_normalize(strategy, T, name_i, F_i, raw_i)
            x_i = _field_validate(strategy, T, name_i, _field_convert(strategy, T, F_i, name_i, raw_i))
            N == i && return Base.@ncall i constructor x
        end
    end
    others = Any[]
    for i in 33:N
        F_i = fieldtype(T, i)
        name_i = fieldnames(T)[i]
        key_i = string(deser_name(strategy, T, Val(name_i)))
        val_ptr_i = yyjson_obj_getn(obj, key_i, sizeof(key_i))
        if val_ptr_i == YYJSONVal_NULL
            raw_i = _field_default(strategy, T, name_i, F_i)
        elseif yyjson_is_null(val_ptr_i)
            raw_i = nothing
        else
            raw_i = _yy_extract(strategy, T, F_i, val_ptr_i)
        end
        raw_i = _field_normalize(strategy, T, name_i, F_i, raw_i)
        push!(others, _field_validate(strategy, T, name_i, _field_convert(strategy, T, F_i, name_i, raw_i)))
    end
    return constructor(
        x_1, x_2, x_3, x_4, x_5, x_6, x_7, x_8, x_9, x_10, x_11, x_12, x_13,
        x_14, x_15, x_16, x_17, x_18, x_19, x_20, x_21, x_22, x_23, x_24, x_25,
        x_26, x_27, x_28, x_29, x_30, x_31, x_32, others...,
    )
end

function _yy_deser_tagged(strategy, ::Type{T}, obj::Ptr{YYJSONVal}) where {T}
    tk = string(tag_key(strategy, T))
    tag_ptr = yyjson_obj_getn(obj, tk, sizeof(tk))
    tag_ptr === YYJSONVal_NULL && throw(Serde.TypeMismatchError(T, Symbol(tk), T, Nothing, nothing))
    tag_val = unsafe_string(yyjson_get_str(tag_ptr))
    for (tv, ST) in tag_subtypes(strategy, T)
        string(tv) == tag_val && return _yy_deser_struct(strategy, ST, obj)
    end
    throw(Serde.TypeMismatchError(T, Symbol(tk), T, String, tag_val))
end

# ── Context-aware deserialization ──

_yy_extract(strategy, ::Type{T}, ::Type{F}, v::Ptr{YYJSONVal}) where {T, F<:Union{String,Bool,Signed,Unsigned,AbstractFloat,AbstractString,Symbol}} = _yy_extract(T, F, v)
_yy_extract(strategy, ::Type, ::Type{Nothing}, v::Ptr{YYJSONVal}) = nothing
_yy_extract(strategy, ::Type, ::Type{Missing}, v::Ptr{YYJSONVal}) = missing

# Nullable with strategy
@inline function _yy_extract(strategy, ::Type{T}, ::Type{Union{Nothing,F}}, v::Ptr{YYJSONVal}) where {T,F}
    yyjson_is_null(v) ? nothing : _yy_extract(strategy, T, F, v)
end

@inline function _yy_extract(strategy, ::Type{T}, ::Type{Union{Missing,F}}, v::Ptr{YYJSONVal}) where {T,F}
    yyjson_is_null(v) ? missing : _yy_extract(strategy, T, F, v)
end

# Vector with strategy
function _yy_extract(strategy, ::Type{T}, ::Type{F}, v::Ptr{YYJSONVal}) where {T, F<:AbstractVector}
    E = eltype(F)
    n = yyjson_arr_size(v)
    result = Vector{E}(undef, n)
    iter = YYJSONArrIter()
    iter_ptr = pointer_from_objref(iter)
    yyjson_arr_iter_init(v, iter_ptr)
    @inbounds for i in 1:n
        result[i] = _yy_extract(strategy, T, E, yyjson_arr_iter_next(iter_ptr))
    end
    return result
end

# Set with strategy
function _yy_extract(strategy, ::Type{T}, ::Type{F}, v::Ptr{YYJSONVal}) where {T, F<:AbstractSet}
    E = eltype(F)
    n = yyjson_arr_size(v)
    result = F()
    iter = YYJSONArrIter()
    iter_ptr = pointer_from_objref(iter)
    yyjson_arr_iter_init(v, iter_ptr)
    for _ in 1:n
        push!(result, _yy_extract(strategy, T, E, yyjson_arr_iter_next(iter_ptr)))
    end
    return result
end

# Tuple with strategy
function _yy_extract(strategy, ::Type{T}, ::Type{F}, v::Ptr{YYJSONVal}) where {T, F<:Tuple}
    types = fieldtypes(F)
    n = length(types)
    vals = Any[_yy_extract(strategy, T, types[i], yyjson_arr_get(v, i - 1)) for i in 1:n]
    return F(vals)
end

# Dict with strategy
function _yy_extract(strategy, ::Type{T}, ::Type{F}, v::Ptr{YYJSONVal}) where {T, F<:AbstractDict}
    V = valtype(F)
    n = yyjson_obj_size(v)
    d = F()
    sizehint!(d, n)
    iter = YYJSONObjIter()
    iter_ptr = pointer_from_objref(iter)
    yyjson_obj_iter_init(v, iter_ptr)
    for _ in 1:n
        key_ptr = yyjson_obj_iter_next(iter_ptr)
        val_ptr = yyjson_obj_iter_get_val(key_ptr)
        k = unsafe_string(yyjson_get_str(key_ptr))
        d[k] = V === Any ? _yy_to_julia(val_ptr) : _yy_extract(strategy, T, V, val_ptr)
    end
    return d
end

# Generic fallback with strategy
function _yy_extract(strategy, ::Type{T}, ::Type{F}, v::Ptr{YYJSONVal}) where {T, F}
    ct = ClassType(F)
    if ct isa StructClass && fieldcount(F) > 0
        return _yy_deser_struct(strategy, F, v)
    end
    return _yy_to_julia(v)
end

# ═══════════════════════════════════════════════════════════════════════════════
# Public API: from_json / try_from_json
# ═══════════════════════════════════════════════════════════════════════════════

"""
    from_json(::Type{T}, x::Union{AbstractString, Vector{UInt8}}) -> T
    from_json(strategy, ::Type{T}, x::Union{AbstractString, Vector{UInt8}}) -> T
    from_json(f::Function, x) -> Any

Parse a JSON string and deserialize it into type `T`.

The JSON backend uses a high-performance C parser (yyjson) and deserializes struct types
directly from the parse tree without creating an intermediate `Dict`.

When called with a function `f` as the first argument, the raw parsed value is passed to
`f` to determine the target type dynamically: `to_deser(f(parsed), parsed)`.

Pass a context object `strategy` (e.g. [`CamelCase()`](@ref)) as the first argument to apply
global field-renaming during deserialization.

# Arguments
- `::Type{T}`: target type to construct.
- `x`: JSON text as a `String` or `Vector{UInt8}`.
- `strategy`: optional context object for field renaming.
- `f::Function`: function `(parsed_data) -> Type` for dynamic type selection.

# Returns
A value of type `T`.

# Throws
- [`ParseError`](@ref): if `x` is malformed JSON.
- [`MissingFieldError`](@ref): if a required struct field is absent.
- [`TypeMismatchError`](@ref): if a value cannot be coerced to the field type.
- [`ValidationError`](@ref): if a custom `deser_validate` check fails.

# Examples
```julia
julia> struct Point; x::Int; y::Int; end

julia> from_json(Point, "{\"x\":1,\"y\":2}")
Point(1, 2)

julia> from_json(CamelCase(), Point, "{\"x\":1,\"y\":2}")
Point(1, 2)

julia> from_json(Vector{Int}, "[1,2,3]")
3-element Vector{Int64}: [1, 2, 3]
```

See also: [`try_from_json`](@ref), [`parse_json`](@ref), [`to_json`](@ref).
"""
function from_json(strategy, ::Type{T}, x::AbstractString; kw...) where {T}
    ct = ClassType(T)
    if ct isa StructClass || ct isa TaggedClass
        doc = _yy_read(x)
        try
            root = yyjson_doc_get_root(doc)
            root === YYJSONVal_NULL && throw(ParseError("JSON", "empty JSON document", ErrorException("empty")))
            return ct isa TaggedClass ? _yy_deser_tagged(strategy, T, root) : _yy_deser_struct(strategy, T, root)
        finally
            yyjson_doc_free(doc)
        end
    else
        doc = _yy_read(x)
        try
            root = yyjson_doc_get_root(doc)
            root === YYJSONVal_NULL && throw(ParseError("JSON", "empty JSON document", ErrorException("empty")))
            return _yy_extract(strategy, Nothing, T, root)
        finally
            yyjson_doc_free(doc)
        end
    end
end

function from_json(strategy, ::Type{T}, x::Vector{UInt8}; kw...) where {T}
    return from_json(strategy, T, unsafe_string(pointer(x), length(x)); kw...)
end

from_json(::Type{T}, x; kw...) where {T} = from_json(DefaultStrategy(), T, x; kw...)
from_json(::Type{Nothing}, _) = nothing
from_json(::Type{Nothing}, ::AbstractString) = nothing
from_json(::Type{Missing}, _) = missing
from_json(::Type{Missing}, ::AbstractString) = missing

function from_json(f::Function, x; kw...)
    object = parse_json(x; kw...)
    return to_deser(f(object), object)
end

# ── Error-safe deserialization ──

function _try_wrap(f, args...; kw...)
    try
        return f(args...; kw...)
    catch e
        return e isa SerdeError ? e : ParseError("JSON", string(e), e)
    end
end

"""
    try_from_json(::Type{T}, x) -> Union{T, SerdeError}
    try_from_json(strategy, ::Type{T}, x) -> Union{T, SerdeError}

Like [`from_json`](@ref) but returns a [`SerdeError`](@ref) instead of throwing on failure.

Useful when processing untrusted input where parse or deserialization errors are expected
and should be handled without try/catch boilerplate.

# Returns
- `T` on success.
- A [`ParseError`](@ref) or [`DeserError`](@ref) subtype on failure.

# Examples
```julia
julia> struct Point; x::Int; y::Int; end

julia> result = try_from_json(Point, "{\"x\":1,\"y\":2}")
Point(1, 2)

julia> result = try_from_json(Point, "not json")
ParseError (JSON): ...

julia> result isa SerdeError
true
```

See also: [`from_json`](@ref), [`SerdeError`](@ref).
"""
try_from_json(::Type{T}, x; kw...)           where {T} = _try_wrap(from_json, T, x; kw...)
try_from_json(strategy, ::Type{T}, x; kw...) where {T} = _try_wrap(from_json, strategy, T, x; kw...)

# ═══════════════════════════════════════════════════════════════════════════════
# Fast serialization via yyjson mutable DOM → C writer
# ═══════════════════════════════════════════════════════════════════════════════

const _yyjson_lib = YYJSON.yyjson_jll.libyyjson

# ── Low-level ccall wrappers ──

@inline _yy_mut_doc_new() =
    ccall((:yyjson_mut_doc_new, _yyjson_lib), Ptr{Cvoid}, (Ptr{Cvoid},), C_NULL)
@inline _yy_mut_doc_free(doc) =
    ccall((:yyjson_mut_doc_free, _yyjson_lib), Cvoid, (Ptr{Cvoid},), doc)
@inline _yy_mut_doc_set_root(doc, root) =
    ccall((:yyjson_mut_doc_set_root, _yyjson_lib), Cvoid, (Ptr{Cvoid}, Ptr{Cvoid}), doc, root)

@inline _yy_mut_obj(doc) =
    ccall((:yyjson_mut_obj, _yyjson_lib), Ptr{Cvoid}, (Ptr{Cvoid},), doc)
@inline _yy_mut_arr(doc) =
    ccall((:yyjson_mut_arr, _yyjson_lib), Ptr{Cvoid}, (Ptr{Cvoid},), doc)
@inline _yy_mut_null(doc) =
    ccall((:yyjson_mut_null, _yyjson_lib), Ptr{Cvoid}, (Ptr{Cvoid},), doc)
@inline _yy_mut_bool(doc, v) =
    ccall((:yyjson_mut_bool, _yyjson_lib), Ptr{Cvoid}, (Ptr{Cvoid}, Bool), doc, v)
@inline _yy_mut_int(doc, v) =
    ccall((:yyjson_mut_sint, _yyjson_lib), Ptr{Cvoid}, (Ptr{Cvoid}, Int64), doc, v)
@inline _yy_mut_uint(doc, v) =
    ccall((:yyjson_mut_uint, _yyjson_lib), Ptr{Cvoid}, (Ptr{Cvoid}, UInt64), doc, v)
@inline _yy_mut_real(doc, v) =
    ccall((:yyjson_mut_real, _yyjson_lib), Ptr{Cvoid}, (Ptr{Cvoid}, Cdouble), doc, v)

# strn: stores pointer without copy — caller must keep string alive
@inline _yy_mut_strn(doc, s::String) =
    ccall((:yyjson_mut_strn, _yyjson_lib), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{UInt8}, Csize_t), doc, s, sizeof(s))

# strcpy: copies string into yyjson arena — safe for temporaries
@inline _yy_mut_strcpy(doc, s::String) =
    ccall((:yyjson_mut_strncpy, _yyjson_lib), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{UInt8}, Csize_t), doc, s, sizeof(s))

# Symbol name pointer (interned, never GC'd — safe for strn)
@inline function _yy_mut_sym(doc, s::Symbol)
    ptr = ccall(:jl_symbol_name, Ptr{UInt8}, (Any,), s)
    len = ccall(:strlen, Csize_t, (Ptr{UInt8},), ptr)
    ccall((:yyjson_mut_strn, _yyjson_lib), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{UInt8}, Csize_t), doc, ptr, len)
end

@inline _yy_mut_obj_add(obj, key, val) =
    ccall((:yyjson_mut_obj_add, _yyjson_lib), Bool, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}), obj, key, val)
@inline _yy_mut_arr_add(arr, val) =
    ccall((:yyjson_mut_arr_add_val, _yyjson_lib), Bool, (Ptr{Cvoid}, Ptr{Cvoid}), arr, val)

@inline function _yy_mut_write(doc)
    len = Ref{Csize_t}(0)
    ptr = ccall((:yyjson_mut_write, _yyjson_lib), Ptr{UInt8}, (Ptr{Cvoid}, UInt32, Ptr{Csize_t}), doc, UInt32(0), len)
    s = unsafe_string(ptr, len[])
    Libc.free(ptr)
    return s
end

# ── Type-dispatched serialization to yyjson_mut_val ──

# Strings: field values use strn (kept alive by struct), others use strcpy
@inline _yy_ser(doc::Ptr{Cvoid}, val::String) = _yy_mut_strn(doc, val)
@inline _yy_ser(doc::Ptr{Cvoid}, val::SubString{String}) = _yy_mut_strcpy(doc, String(val))
@inline _yy_ser(doc::Ptr{Cvoid}, val::AbstractString) = _yy_mut_strcpy(doc, string(val))

# Symbols: interned pointers, safe for strn
@inline _yy_ser(doc::Ptr{Cvoid}, val::Symbol) = _yy_mut_sym(doc, val)

# Numbers
@inline _yy_ser(doc::Ptr{Cvoid}, val::Bool) = _yy_mut_bool(doc, val)
@inline _yy_ser(doc::Ptr{Cvoid}, val::Int64) = _yy_mut_int(doc, val)
@inline _yy_ser(doc::Ptr{Cvoid}, val::Int32) = _yy_mut_int(doc, Int64(val))
@inline _yy_ser(doc::Ptr{Cvoid}, val::Int16) = _yy_mut_int(doc, Int64(val))
@inline _yy_ser(doc::Ptr{Cvoid}, val::Int8) = _yy_mut_int(doc, Int64(val))
@inline _yy_ser(doc::Ptr{Cvoid}, val::Int128) = _yy_mut_int(doc, Int64(val))
@inline _yy_ser(doc::Ptr{Cvoid}, val::UInt64) = _yy_mut_uint(doc, val)
@inline _yy_ser(doc::Ptr{Cvoid}, val::UInt32) = _yy_mut_uint(doc, UInt64(val))
@inline _yy_ser(doc::Ptr{Cvoid}, val::UInt16) = _yy_mut_uint(doc, UInt64(val))
@inline _yy_ser(doc::Ptr{Cvoid}, val::UInt8) = _yy_mut_uint(doc, UInt64(val))
@inline _yy_ser(doc::Ptr{Cvoid}, val::UInt128) = _yy_mut_uint(doc, UInt64(val))

@inline function _yy_ser(doc::Ptr{Cvoid}, val::AbstractFloat)
    (isnan(val) || isinf(val)) && return _yy_mut_null(doc)
    return _yy_mut_real(doc, Float64(val))
end

@inline function _yy_ser(doc::Ptr{Cvoid}, val::Number)
    (isnan(val) || isinf(val)) && return _yy_mut_null(doc)
    return _yy_mut_real(doc, Float64(val))
end

# Nulls
@inline _yy_ser(doc::Ptr{Cvoid}, ::Nothing) = _yy_mut_null(doc)
@inline _yy_ser(doc::Ptr{Cvoid}, ::Missing) = _yy_mut_null(doc)

# Types that convert to string (use strcpy since string() creates temporaries)
@inline _yy_ser(doc::Ptr{Cvoid}, val::Enum) = _yy_mut_strcpy(doc, string(val))
@inline _yy_ser(doc::Ptr{Cvoid}, val::AbstractChar) = _yy_mut_strcpy(doc, string(val))
@inline _yy_ser(doc::Ptr{Cvoid}, val::Type) = _yy_mut_strcpy(doc, string(val))
@inline _yy_ser(doc::Ptr{Cvoid}, val::Dates.TimeType) = _yy_mut_strcpy(doc, string(val))
@inline _yy_ser(doc::Ptr{Cvoid}, val::UUID) = _yy_mut_strcpy(doc, string(val))

# Collections
function _yy_ser(doc::Ptr{Cvoid}, val::AbstractVector)
    arr = _yy_mut_arr(doc)
    @inbounds for item in val
        _yy_mut_arr_add(arr, _yy_ser(doc, item))
    end
    return arr
end

function _yy_ser(doc::Ptr{Cvoid}, val::AbstractSet)
    arr = _yy_mut_arr(doc)
    for item in val
        _yy_mut_arr_add(arr, _yy_ser(doc, item))
    end
    return arr
end

function _yy_ser(doc::Ptr{Cvoid}, val::Tuple)
    arr = _yy_mut_arr(doc)
    for item in val
        _yy_mut_arr_add(arr, _yy_ser(doc, item))
    end
    return arr
end

function _yy_ser(doc::Ptr{Cvoid}, val::AbstractDict)
    obj = _yy_mut_obj(doc)
    for (k, v) in val
        key = k isa Symbol ? _yy_mut_sym(doc, k) : _yy_mut_strcpy(doc, string(k))
        _yy_mut_obj_add(obj, key, _yy_ser(doc, v))
    end
    return obj
end

function _yy_ser(doc::Ptr{Cvoid}, val::Pair)
    obj = _yy_mut_obj(doc)
    k = first(val)
    key = k isa Symbol ? _yy_mut_sym(doc, k) : _yy_mut_strcpy(doc, string(k))
    _yy_mut_obj_add(obj, key, _yy_ser(doc, last(val)))
    return obj
end

function _yy_ser(doc::Ptr{Cvoid}, val::NamedTuple)
    obj = _yy_mut_obj(doc)
    for k in keys(val)
        _yy_mut_obj_add(obj, _yy_mut_sym(doc, k), _yy_ser(doc, val[k]))
    end
    return obj
end

# Struct serialization with @nexprs unrolling
function _yy_ser(doc::Ptr{Cvoid}, val::T) where {T}
    obj = _yy_mut_obj(doc)
    N = fieldcount(T)
    Base.@nexprs 32 i -> begin
        if i <= N
            fn_i = fieldnames(T)[i]
            k_i = ser_name(T, Val(fn_i))
            v_i = ser_type(T, ser_value(T, Val(fn_i), getfield(val, fn_i)))
            if !ser_skip(T, Val(fn_i), v_i)
                _yy_mut_obj_add(obj, _yy_mut_sym(doc, k_i), _yy_ser(doc, v_i))
            end
        end
    end
    if N > 32
        for field in fieldnames(T)[33:end]
            k = ser_name(T, Val(field))
            v = ser_type(T, ser_value(T, Val(field), getfield(val, field)))
            ser_skip(T, Val(field), v) && continue
            _yy_mut_obj_add(obj, _yy_mut_sym(doc, k), _yy_ser(doc, v))
        end
    end
    return obj
end

# ── Context-aware yyjson serialization ──

_yy_ser(doc::Ptr{Cvoid}, strategy, val::String) = _yy_ser(doc, val)
_yy_ser(doc::Ptr{Cvoid}, strategy, val::SubString{String}) = _yy_ser(doc, val)
_yy_ser(doc::Ptr{Cvoid}, strategy, val::AbstractString) = _yy_ser(doc, val)
_yy_ser(doc::Ptr{Cvoid}, strategy, val::Symbol) = _yy_ser(doc, val)
_yy_ser(doc::Ptr{Cvoid}, strategy, val::Bool) = _yy_ser(doc, val)
_yy_ser(doc::Ptr{Cvoid}, strategy, val::Integer) = _yy_ser(doc, val)
_yy_ser(doc::Ptr{Cvoid}, strategy, val::AbstractFloat) = _yy_ser(doc, val)
_yy_ser(doc::Ptr{Cvoid}, strategy, val::Number) = _yy_ser(doc, val)
_yy_ser(doc::Ptr{Cvoid}, strategy, ::Nothing) = _yy_mut_null(doc)
_yy_ser(doc::Ptr{Cvoid}, strategy, ::Missing) = _yy_mut_null(doc)
_yy_ser(doc::Ptr{Cvoid}, strategy, val::Enum) = _yy_ser(doc, val)
_yy_ser(doc::Ptr{Cvoid}, strategy, val::AbstractChar) = _yy_ser(doc, val)
_yy_ser(doc::Ptr{Cvoid}, strategy, val::Type) = _yy_ser(doc, val)
_yy_ser(doc::Ptr{Cvoid}, strategy, val::Dates.TimeType) = _yy_ser(doc, val)
_yy_ser(doc::Ptr{Cvoid}, strategy, val::UUID) = _yy_ser(doc, val)

# Compound types: forward strategy
function _yy_ser(doc::Ptr{Cvoid}, strategy, val::AbstractVector)
    arr = _yy_mut_arr(doc)
    @inbounds for item in val
        _yy_mut_arr_add(arr, _yy_ser(doc, strategy, item))
    end
    return arr
end

function _yy_ser(doc::Ptr{Cvoid}, strategy, val::AbstractSet)
    arr = _yy_mut_arr(doc)
    for item in val
        _yy_mut_arr_add(arr, _yy_ser(doc, strategy, item))
    end
    return arr
end

function _yy_ser(doc::Ptr{Cvoid}, strategy, val::Tuple)
    arr = _yy_mut_arr(doc)
    for item in val
        _yy_mut_arr_add(arr, _yy_ser(doc, strategy, item))
    end
    return arr
end

function _yy_ser(doc::Ptr{Cvoid}, strategy, val::AbstractDict)
    obj = _yy_mut_obj(doc)
    for (k, v) in val
        key = k isa Symbol ? _yy_mut_sym(doc, k) : _yy_mut_strcpy(doc, string(k))
        _yy_mut_obj_add(obj, key, _yy_ser(doc, strategy, v))
    end
    return obj
end

function _yy_ser(doc::Ptr{Cvoid}, strategy, val::Pair)
    obj = _yy_mut_obj(doc)
    k = first(val)
    key = k isa Symbol ? _yy_mut_sym(doc, k) : _yy_mut_strcpy(doc, string(k))
    _yy_mut_obj_add(obj, key, _yy_ser(doc, strategy, last(val)))
    return obj
end

function _yy_ser(doc::Ptr{Cvoid}, strategy, val::NamedTuple)
    obj = _yy_mut_obj(doc)
    for k in keys(val)
        _yy_mut_obj_add(obj, _yy_mut_sym(doc, k), _yy_ser(doc, strategy, val[k]))
    end
    return obj
end

# Struct serialization with strategy
function _yy_ser(doc::Ptr{Cvoid}, strategy, val::T) where {T}
    obj = _yy_mut_obj(doc)
    N = fieldcount(T)
    Base.@nexprs 32 i -> begin
        if i <= N
            fn_i = fieldnames(T)[i]
            k_i = ser_name(strategy, T, Val(fn_i))
            v_i = ser_type(strategy, T, ser_value(strategy, T, Val(fn_i), getfield(val, fn_i)))
            if !ser_skip(strategy, T, Val(fn_i), v_i)
                _yy_mut_obj_add(obj, _yy_mut_sym(doc, k_i), _yy_ser(doc, strategy, v_i))
            end
        end
    end
    if N > 32
        for field in fieldnames(T)[33:end]
            k = ser_name(strategy, T, Val(field))
            v = ser_type(strategy, T, ser_value(strategy, T, Val(field), getfield(val, field)))
            ser_skip(strategy, T, Val(field), v) && continue
            _yy_mut_obj_add(obj, _yy_mut_sym(doc, k), _yy_ser(doc, strategy, v))
        end
    end
    return obj
end

# ═══════════════════════════════════════════════════════════════════════════════
# IOBuffer serialization (fallback for pretty printing, IO output, custom fields)
# ═══════════════════════════════════════════════════════════════════════════════

const _JSON_NULL = "null"
const _json_float_buf = Vector{UInt8}(undef, 32)

# Zero-alloc Symbol key writer: writes "key": without allocating a String
@inline function _json_write_key!(io::IO, key::Symbol)
    write(io, UInt8('"'))
    ptr = ccall(:jl_symbol_name, Ptr{UInt8}, (Any,), key)
    len = ccall(:strlen, Csize_t, (Ptr{UInt8},), ptr)
    unsafe_write(io, ptr, len)
    write(io, UInt8('"'))
end

@inline function _json_write_key!(io::IO, key::AbstractString)
    write(io, UInt8('"'))
    if _json_needs_escape(key)
        escape_string(io, key)
    else
        write(io, key)
    end
    write(io, UInt8('"'))
end

@inline function _json_write_key!(io::IO, key)
    write(io, UInt8('"'))
    print(io, key)
    write(io, UInt8('"'))
end

@inline _json_nextlevel(l::Int) = l + (l > -1)

const _JSON_INDENTS = let
    v = String[""]
    for i in 1:32
        push!(v, "\n" * "  "^i)
    end
    v
end

@inline function _json_indent!(io::IO, l::Int)
    l < 0 && return
    if l < length(_JSON_INDENTS)
        write(io, _JSON_INDENTS[l + 1])
    else
        print(io, '\n')
        for _ in 1:l
            write(io, "  ")
        end
    end
end

@inline function _json_needs_escape(val::AbstractString)
    for c in val
        (c == '"' || c == '\\' || iscntrl(c)) && return true
    end
    return false
end

function _json_value!(io::IO, f::Function, val::AbstractString; kw...)
    write(io, UInt8('"'))
    if _json_needs_escape(val)
        escape_string(io, val)
    else
        write(io, val)
    end
    write(io, UInt8('"'))
end

_json_value!(io::IO, f::Function, val::Symbol; kw...) = _json_value!(io, f, string(val); kw...)
_json_value!(io::IO, f::Function, val::Dates.TimeType; kw...) = _json_value!(io, f, string(val); kw...)
_json_value!(io::IO, f::Function, val::UUID; kw...) = _json_value!(io, f, string(val); kw...)
_json_value!(io::IO, f::Function, val::AbstractChar; kw...) = (write(io, UInt8('"')); print(io, val); write(io, UInt8('"')))
_json_value!(io::IO, f::Function, val::Bool; kw...) = write(io, val ? "true" : "false")

@inline function _json_write_int!(io::IO, n::UInt64)
    n >= 10 && _json_write_int!(io, div(n, 10))
    write(io, UInt8('0') + rem(n, 10) % UInt8)
end

function _json_value!(io::IO, f::Function, val::Integer; kw...)
    if val < 0
        write(io, UInt8('-'))
        _json_write_int!(io, unsigned(-val))
    else
        _json_write_int!(io, unsigned(val))
    end
end

function _json_value!(io::IO, f::Function, val::AbstractFloat; kw...)
    if isnan(val) || isinf(val)
        write(io, _JSON_NULL)
    else
        n = Base.Ryu.writeshortest(_json_float_buf, 1, Float64(val))
        unsafe_write(io, pointer(_json_float_buf), n - 1)
    end
end

function _json_value!(io::IO, f::Function, val::Number; kw...)
    isnan(val) || isinf(val) ? write(io, _JSON_NULL) : print(io, val)
end

_json_value!(io::IO, f::Function, val::Enum; kw...) = (write(io, UInt8('"')); print(io, val); write(io, UInt8('"')))
_json_value!(io::IO, f::Function, val::Missing; kw...) = write(io, _JSON_NULL)
_json_value!(io::IO, f::Function, val::Nothing; kw...) = write(io, _JSON_NULL)
_json_value!(io::IO, f::Function, val::Type; kw...) = (write(io, UInt8('"')); print(io, val); write(io, UInt8('"')))

function _json_value!(io::IO, f::Function, val::Pair; l::Int, kw...)
    nl = _json_nextlevel(l)
    write(io, UInt8('{'))
    _json_indent!(io, l)
    _json_write_key!(io, first(val))
    write(io, UInt8(':'))
    _json_value!(io, f, last(val); l = nl, kw...)
    _json_indent!(io, l - 1)
    write(io, UInt8('}'))
end

function _json_value!(io::IO, f::Function, val::AbstractDict; l::Int, kw...)
    nl = _json_nextlevel(l)
    write(io, UInt8('{'))
    first_entry = true
    for (k, v) in val
        if first_entry
            first_entry = false
        else
            write(io, UInt8(','))
        end
        _json_indent!(io, l)
        _json_write_key!(io, k)
        write(io, UInt8(':'))
        _json_value!(io, f, v; l = nl, kw...)
    end
    _json_indent!(io, l - 1)
    write(io, UInt8('}'))
end

function _json_iterable!(io::IO, f::Function, iter; l::Int, kw...)
    nl = _json_nextlevel(l)
    write(io, UInt8('['))
    first_entry = true
    for item in iter
        if first_entry
            first_entry = false
        else
            write(io, UInt8(','))
        end
        _json_indent!(io, l)
        _json_value!(io, f, item; l = nl, kw...)
    end
    _json_indent!(io, l - 1)
    write(io, UInt8(']'))
end

_json_value!(io::IO, f::Function, val::AbstractVector; l::Int, kw...) = _json_iterable!(io, f, val; l, kw...)
_json_value!(io::IO, f::Function, val::Tuple; l::Int, kw...) = _json_iterable!(io, f, val; l, kw...)
_json_value!(io::IO, f::Function, val::AbstractSet; l::Int, kw...) = _json_iterable!(io, f, val; l, kw...)

function _json_value!(io::IO, f::Function, A::AbstractArray{<:Any,n}; l::Int, kw...) where {n}
    nl = _json_nextlevel(l)
    newdims = ntuple(_ -> :, n - 1)
    write(io, UInt8('['))
    first_entry = true
    for j in axes(A, n)
        if first_entry
            first_entry = false
        else
            write(io, UInt8(','))
        end
        _json_indent!(io, l)
        _json_value!(io, f, view(A, newdims..., j); l = nl, kw...)
    end
    _json_indent!(io, l - 1)
    write(io, UInt8(']'))
end

function _json_value!(io::IO, f::Function, val::T; l::Int, kw...) where {T}
    nl = _json_nextlevel(l)
    write(io, UInt8('{'))
    N = fieldcount(T)
    _first = true
    if f === fieldnames
        Base.@nexprs 32 i -> begin
            if i <= N
                fn_i = fieldnames(T)[i]
                k_i = ser_name(T, Val(fn_i))
                v_i = ser_type(T, ser_value(T, Val(fn_i), getfield(val, fn_i)))
                if !ser_skip(T, Val(fn_i), v_i)
                    _first || write(io, UInt8(','))
                    _first = false
                    _json_indent!(io, l)
                    _json_write_key!(io, k_i)
                    write(io, UInt8(':'))
                    _json_value!(io, f, v_i; l = nl, kw...)
                end
            end
        end
        if N > 32
            for field in fieldnames(T)[33:end]
                k = ser_name(T, Val(field))
                v = ser_type(T, ser_value(T, Val(field), getfield(val, field)))
                ser_skip(T, Val(field), v) && continue
                _first || write(io, UInt8(','))
                _first = false
                _json_indent!(io, l)
                _json_write_key!(io, k)
                write(io, UInt8(':'))
                _json_value!(io, f, v; l = nl, kw...)
            end
        end
    else
        for field in f(T)
            k = ser_name(T, Val(field))
            v = ser_type(T, ser_value(T, Val(field), getfield(val, field)))
            ser_skip(T, Val(field), v) && continue
            _first || write(io, UInt8(','))
            _first = false
            _json_indent!(io, l)
            _json_write_key!(io, k)
            write(io, UInt8(':'))
            _json_value!(io, f, v; l = nl, kw...)
        end
    end
    _json_indent!(io, l - 1)
    write(io, UInt8('}'))
end

function _json_value!(io::IO, val::T; l::Int, kw...) where {T}
    return _json_value!(io, fieldnames, val; l, kw...)
end

# ── Context-aware IOBuffer serialization ──

_json_value!(io::IO, strategy, f::Function, val::AbstractString; kw...) = _json_value!(io, f, val; kw...)
_json_value!(io::IO, strategy, f::Function, val::Symbol; kw...) = _json_value!(io, f, val; kw...)
_json_value!(io::IO, strategy, f::Function, val::Dates.TimeType; kw...) = _json_value!(io, f, val; kw...)
_json_value!(io::IO, strategy, f::Function, val::UUID; kw...) = _json_value!(io, f, val; kw...)
_json_value!(io::IO, strategy, f::Function, val::AbstractChar; kw...) = _json_value!(io, f, val; kw...)
_json_value!(io::IO, strategy, f::Function, val::Bool; kw...) = _json_value!(io, f, val; kw...)
_json_value!(io::IO, strategy, f::Function, val::Integer; kw...) = _json_value!(io, f, val; kw...)
_json_value!(io::IO, strategy, f::Function, val::AbstractFloat; kw...) = _json_value!(io, f, val; kw...)
_json_value!(io::IO, strategy, f::Function, val::Number; kw...) = _json_value!(io, f, val; kw...)
_json_value!(io::IO, strategy, f::Function, val::Enum; kw...) = _json_value!(io, f, val; kw...)
_json_value!(io::IO, strategy, f::Function, val::Missing; kw...) = _json_value!(io, f, val; kw...)
_json_value!(io::IO, strategy, f::Function, val::Nothing; kw...) = _json_value!(io, f, val; kw...)
_json_value!(io::IO, strategy, f::Function, val::Type; kw...) = _json_value!(io, f, val; kw...)

# Compound types with strategy
function _json_value!(io::IO, strategy, f::Function, val::Pair; l::Int, kw...)
    nl = _json_nextlevel(l)
    write(io, UInt8('{'))
    _json_indent!(io, l)
    _json_write_key!(io, first(val))
    write(io, UInt8(':'))
    _json_value!(io, strategy, f, last(val); l = nl, kw...)
    _json_indent!(io, l - 1)
    write(io, UInt8('}'))
end

function _json_value!(io::IO, strategy, f::Function, val::AbstractDict; l::Int, kw...)
    nl = _json_nextlevel(l)
    write(io, UInt8('{'))
    first_entry = true
    for (k, v) in val
        if first_entry
            first_entry = false
        else
            write(io, UInt8(','))
        end
        _json_indent!(io, l)
        _json_write_key!(io, k)
        write(io, UInt8(':'))
        _json_value!(io, strategy, f, v; l = nl, kw...)
    end
    _json_indent!(io, l - 1)
    write(io, UInt8('}'))
end

function _json_iterable!(io::IO, strategy, f::Function, iter; l::Int, kw...)
    nl = _json_nextlevel(l)
    write(io, UInt8('['))
    first_entry = true
    for item in iter
        if first_entry
            first_entry = false
        else
            write(io, UInt8(','))
        end
        _json_indent!(io, l)
        _json_value!(io, strategy, f, item; l = nl, kw...)
    end
    _json_indent!(io, l - 1)
    write(io, UInt8(']'))
end

_json_value!(io::IO, strategy, f::Function, val::AbstractVector; l::Int, kw...) = _json_iterable!(io, strategy, f, val; l, kw...)
_json_value!(io::IO, strategy, f::Function, val::Tuple; l::Int, kw...) = _json_iterable!(io, strategy, f, val; l, kw...)
_json_value!(io::IO, strategy, f::Function, val::AbstractSet; l::Int, kw...) = _json_iterable!(io, strategy, f, val; l, kw...)

function _json_value!(io::IO, strategy, f::Function, A::AbstractArray{<:Any,n}; l::Int, kw...) where {n}
    nl = _json_nextlevel(l)
    newdims = ntuple(_ -> :, n - 1)
    write(io, UInt8('['))
    first_entry = true
    for j in axes(A, n)
        if first_entry
            first_entry = false
        else
            write(io, UInt8(','))
        end
        _json_indent!(io, l)
        _json_value!(io, strategy, f, view(A, newdims..., j); l = nl, kw...)
    end
    _json_indent!(io, l - 1)
    write(io, UInt8(']'))
end

function _json_value!(io::IO, strategy, f::Function, val::T; l::Int, kw...) where {T}
    nl = _json_nextlevel(l)
    write(io, UInt8('{'))
    N = fieldcount(T)
    _first = true
    if f === fieldnames
        Base.@nexprs 32 i -> begin
            if i <= N
                fn_i = fieldnames(T)[i]
                k_i = ser_name(strategy, T, Val(fn_i))
                v_i = ser_type(strategy, T, ser_value(strategy, T, Val(fn_i), getfield(val, fn_i)))
                if !ser_skip(strategy, T, Val(fn_i), v_i)
                    _first || write(io, UInt8(','))
                    _first = false
                    _json_indent!(io, l)
                    _json_write_key!(io, k_i)
                    write(io, UInt8(':'))
                    _json_value!(io, strategy, f, v_i; l = nl, kw...)
                end
            end
        end
        if N > 32
            for field in fieldnames(T)[33:end]
                k = ser_name(strategy, T, Val(field))
                v = ser_type(strategy, T, ser_value(strategy, T, Val(field), getfield(val, field)))
                ser_skip(strategy, T, Val(field), v) && continue
                _first || write(io, UInt8(','))
                _first = false
                _json_indent!(io, l)
                _json_write_key!(io, k)
                write(io, UInt8(':'))
                _json_value!(io, strategy, f, v; l = nl, kw...)
            end
        end
    else
        for field in f(T)
            k = ser_name(strategy, T, Val(field))
            v = ser_type(strategy, T, ser_value(strategy, T, Val(field), getfield(val, field)))
            ser_skip(strategy, T, Val(field), v) && continue
            _first || write(io, UInt8(','))
            _first = false
            _json_indent!(io, l)
            _json_write_key!(io, k)
            write(io, UInt8(':'))
            _json_value!(io, strategy, f, v; l = nl, kw...)
        end
    end
    _json_indent!(io, l - 1)
    write(io, UInt8('}'))
end

"""
    to_json(data; pretty::Bool = false) -> String
    to_json(strategy, data; pretty::Bool = false) -> String
    to_json(f::Function, data; pretty::Bool = false) -> String
    to_json(io::IO, data; pretty::Bool = false)

Serialize `data` into a JSON string.

The compact (non-pretty) path uses a native C yyjson writer for maximum throughput.
The pretty path uses an IOBuffer-based writer that produces two-space indented output.

Pass a context object `strategy` (e.g. [`CamelCase()`](@ref)) as the first argument to apply
global field-renaming during serialization.

Pass a function `f(::Type{T}) -> Tuple{Symbol...}` to include only a specific subset
of fields in the output. The function receives the struct type and must return a tuple
of field name symbols.

When an `io::IO` is given as the first argument, JSON is written directly to that stream
and the function returns `nothing`.

All serialization traits ([`Serde.ser_name`](@ref), [`Serde.ser_value`](@ref),
[`Serde.ser_type`](@ref), [`Serde.ser_skip`](@ref)) are applied.

# Arguments
- `data`: the value to serialize (struct, dict, array, or scalar).
- `strategy`: optional context object.
- `f::Function`: optional field selector `(Type) -> Tuple{Symbol...}`.
- `io::IO`: optional output stream.

# Keyword arguments
- `pretty::Bool = false`: emit indented, human-readable JSON.

# Returns
`String` (or `nothing` when writing to `io`).

# Examples
```julia
julia> struct Point; x::Int; y::Int; end

julia> to_json(Point(1, 2))
"{\"x\":1,\"y\":2}"

julia> to_json(CamelCase(), Point(1, 2))  # no renaming needed here, fields are single-char
"{\"x\":1,\"y\":2}"

julia> to_json(Point(1, 2); pretty=true) |> println
{
  "x":1,
  "y":2
}

julia> to_json(T -> (:x,), Point(1, 2))  # only serialize :x
"{\"x\":1}"
```

See also: [`to_pretty_json`](@ref), [`from_json`](@ref).
"""
function to_json(val; pretty::Bool = false, kw...)::String
    if pretty
        io = IOBuffer()
        try
            _json_value!(io, fieldnames, val; l = 1, kw...)
            return String(take!(io))
        finally
            close(io)
        end
    end
    doc = _yy_mut_doc_new()
    try
        root = _yy_ser(doc, val)
        _yy_mut_doc_set_root(doc, root)
        return _yy_mut_write(doc)
    finally
        _yy_mut_doc_free(doc)
    end
end

function to_json(f::Function, val; pretty::Bool = false, kw...)::String
    io = IOBuffer()
    try
        _json_value!(io, f, val; l = pretty ? 1 : -1, kw...)
        return String(take!(io))
    finally
        close(io)
    end
end

function to_json(io::IO, x...; pretty::Bool = false, kw...)
    _json_value!(io, x...; l = pretty ? 1 : -1, kw...)
    return nothing
end

"""
    to_pretty_json(data) -> String
    to_pretty_json(strategy, data) -> String
    to_pretty_json(f::Function, data) -> String

Serialize `data` into a human-readable, indented JSON string.

Alias for `to_json(data; pretty=true)`. Accepts the same optional context `strategy` and
field-selector function `f` as [`to_json`](@ref).

# Examples
```julia
julia> struct Config; host::String; port::Int; end

julia> to_pretty_json(Config("localhost", 8080)) |> println
{
  "host":"localhost",
  "port":8080
}
```

See also: [`to_json`](@ref).
"""
function to_pretty_json(x...; kw...)::String
    return to_json(x...; pretty = true, kw...)
end

function to_json(strategy, val; pretty::Bool = false, kw...)::String
    if pretty
        io = IOBuffer()
        try
            _json_value!(io, strategy, fieldnames, val; l = 1, kw...)
            return String(take!(io))
        finally
            close(io)
        end
    end
    doc = _yy_mut_doc_new()
    try
        root = _yy_ser(doc, strategy, val)
        _yy_mut_doc_set_root(doc, root)
        return _yy_mut_write(doc)
    finally
        _yy_mut_doc_free(doc)
    end
end

function to_json(strategy, f::Function, val; pretty::Bool = false, kw...)::String
    io = IOBuffer()
    try
        _json_value!(io, strategy, f, val; l = pretty ? 1 : -1, kw...)
        return String(take!(io))
    finally
        close(io)
    end
end

function to_json(strategy, io::IO, x...; pretty::Bool = false, kw...)
    _json_value!(io, strategy, fieldnames, x...; l = pretty ? 1 : -1, kw...)
    return nothing
end

function to_pretty_json(strategy, x...; kw...)::String
    return to_json(strategy, x...; pretty = true, kw...)
end

end
