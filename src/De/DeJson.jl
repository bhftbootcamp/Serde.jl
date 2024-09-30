module DeJson

export deser_json

using ..ParJson
using YYJSON
using Serde

import ..Serde: WrongType, ClassType, CustomType, NullType, PrimitiveType, ArrayType, DictType, NTupleType

function typeof_yyjson_val(val_ptr::Ptr{YYJSONVal})
    return if yyjson_is_str(val_ptr)
        String
    elseif yyjson_is_raw(val_ptr)
        String
    elseif yyjson_is_real(val_ptr)
        Float64
    elseif yyjson_is_int(val_ptr)
        Int
    elseif yyjson_is_bool(val_ptr)
        Bool
    elseif yyjson_is_obj(val_ptr)
        Dict{String,Any}
    elseif yyjson_is_arr(val_ptr)
        Vector{Any}
    elseif yyjson_is_null(val_ptr)
        Nothing
    else
        Any
    end
end

# Any

function yyjson_deser(::Type{Any}, val_ptr::Ptr{YYJSONVal})
    return if yyjson_is_str(val_ptr)
        unsafe_string(yyjson_get_str(val_ptr))
    elseif yyjson_is_raw(val_ptr)
        unsafe_string(yyjson_get_raw(val_ptr))
    elseif yyjson_is_real(val_ptr)
        yyjson_get_real(val_ptr)
    elseif yyjson_is_int(val_ptr)
        Int(yyjson_get_num(val_ptr))
    elseif yyjson_is_bool(val_ptr)
        yyjson_get_bool(val_ptr)
    elseif yyjson_is_obj(val_ptr)
        yyjson_deser(Dict{String,Any}, val_ptr)
    elseif yyjson_is_arr(val_ptr)
        yyjson_deser(Vector{Any}, val_ptr)
    end
end

function yyjson_deser(::Type{T}, ::Type{Union{Nothing,E}}, val_ptr::Ptr{YYJSONVal}) where {T,E}
    return yyjson_deser(T, E, val_ptr)
end

# function yyjson_deser(::Type{T}, ::Type{E}, val_ptr::Ptr{YYJSONVal}) where {T,E}
#     return yyjson_deser(E, val_ptr)
# end

function yyjson_deser(::Type{T}, ::Type{Nothing}, val_ptr::Ptr{YYJSONVal}) where {T}
    return yyjson_deser(Nothing, val_ptr)
end

function yyjson_deser(::Type{T}, val_ptr::Ptr{YYJSONVal}) where {T}
    return yyjson_deser(ClassType(T), T, val_ptr)
end

function yyjson_deser(::Type{Union{Nothing,T}}, val_ptr::Ptr{YYJSONVal}) where {T}
    return yyjson_deser(T, val_ptr)
end

function yyjson_deser(::Type{Union{Missing,T}}, val_ptr::Ptr{YYJSONVal}) where {T}
    return yyjson_deser(T, val_ptr)
end

# function yyjson_deser(::PrimitiveType, ::Type{T}, val_ptr::Ptr{YYJSONVal}) where {T}
#     return yyjson_deser(Any, val_ptr)
# end

function yyjson_deser(type::ClassType, ::Type{T}, val_ptr::Ptr{YYJSONVal}) where {T}
    return yyjson_deser(type, T, val_ptr, typeof_yyjson_val(val_ptr))
end

# NOTE: Highly decrease performance but allows to define custom Serde.deser(...) behavior
function yyjson_deser(::Type{T}, ::Type{E}, val_ptr::Ptr{YYJSONVal}) where {T,E}
    return if parentmodule(Serde.deser, (Type{T},Type{E},Any)) != Serde
        Serde.deser(T, E, yyjson_deser(Any, val_ptr))
    else
        yyjson_deser(E, val_ptr)
    end
end

# NOTE: Increase performance but disables custom Serde.deser(...) behavior
# function yyjson_deser(::Type{T}, ::Type{E}, val_ptr::Ptr{YYJSONVal}) where {T,E}
#     return yyjson_deser(E, val_ptr)
# end

# PrimitiveType

function yyjson_deser(::PrimitiveType, ::Type{T}, val_ptr::Ptr{YYJSONVal}, ::Type{String}) where {T<:AbstractString}
    return if yyjson_is_str(val_ptr)
        unsafe_string(yyjson_get_str(val_ptr))
    elseif yyjson_is_raw(val_ptr)
        unsafe_string(yyjson_get_raw(val_ptr))
    end
end

function yyjson_deser(::PrimitiveType, ::Type{T}, val_ptr::Ptr{YYJSONVal}, ::Type{<:Number}) where {T<:AbstractString}
    return if yyjson_is_real(val_ptr)
        repr(yyjson_get_num(val_ptr))
    elseif yyjson_is_int(val_ptr)
        repr(Int64(yyjson_get_num(val_ptr)))
    elseif yyjson_is_bool(val_ptr)
        repr(yyjson_get_bool(val_ptr))
    end
end

function yyjson_deser(::PrimitiveType, ::Type{T}, val_ptr::Ptr{YYJSONVal}, ::Type{String}) where {T<:Number}
    return if yyjson_is_str(val_ptr)
        tryparse(T, unsafe_string(yyjson_get_str(val_ptr)))
    elseif yyjson_is_raw(val_ptr)
        tryparse(T, unsafe_string(yyjson_get_raw(val_ptr)))
    end
end

function yyjson_deser(::PrimitiveType, ::Type{T}, val_ptr::Ptr{YYJSONVal}, ::Type{<:Number}) where {T<:Number}
    return if yyjson_is_real(val_ptr)
        T(yyjson_get_num(val_ptr))
    elseif yyjson_is_int(val_ptr)
        T(Int64(yyjson_get_num(val_ptr)))
    elseif yyjson_is_bool(val_ptr)
        T(yyjson_get_bool(val_ptr))
    end
end

function yyjson_deser(type::PrimitiveType, ::Type{T}, val_ptr::Ptr{YYJSONVal}, ::Type{String}) where {T<:Enum}
    return if yyjson_is_str(val_ptr)
        str = unsafe_string(yyjson_get_str(val_ptr))
        num = tryparse(Int64, str)
        isnothing(num) ? Serde.deser(type, T, Symbol(str)) : Serde.deser(type, T, num)
    elseif yyjson_is_raw(val_ptr)
        str = unsafe_string(yyjson_get_raw(val_ptr))
        num = tryparse(Int64, str)
        isnothing(num) ? Serde.deser(type, T, Symbol(str)) : Serde.deser(type, T, num)
    end
end

function yyjson_deser(::PrimitiveType, ::Type{T}, val_ptr::Ptr{YYJSONVal}, ::Type{<:Number}) where {T<:Enum}
    return if yyjson_is_real(val_ptr)
        T(Int64(yyjson_get_num(val_ptr)))
    elseif yyjson_is_int(val_ptr)
        T(Int64(yyjson_get_num(val_ptr)))
    elseif yyjson_is_bool(val_ptr)
        T(Int64(yyjson_get_bool(val_ptr)))
    end
end

function yyjson_deser(::PrimitiveType, ::Type{T}, val_ptr::Ptr{YYJSONVal}, ::Type{String}) where {T<:Symbol}
    return if yyjson_is_str(val_ptr)
        Symbol(unsafe_string(yyjson_get_str(val_ptr)))
    elseif yyjson_is_raw(val_ptr)
        Symbol(unsafe_string(yyjson_get_raw(val_ptr)))
    end
end

# NullType

function yyjson_deser(::NullType, ::Type{Nothing}, val_ptr::Ptr{YYJSONVal}, ::Type{Nothing})
    return nothing
end

function yyjson_deser(::NullType, ::Type{Missing}, val_ptr::Ptr{YYJSONVal}, ::Type{Missing})
    return  missing
end

function yyjson_deser(::NullType, ::Type{Union{Nothing,T}}, val_ptr::Ptr{YYJSONVal}, ::Type{Nothing}) where {T}
    return yyjson_deser(T, val_ptr)
end

function yyjson_deser(::NullType, ::Type{Union{Missing,T}}, val_ptr::Ptr{YYJSONVal}, ::Type{Missing}) where {T}
    return yyjson_deser(T, val_ptr)
end

# NTupleType

function yyjson_deser(::NTupleType, ::Type{T}, val_ptr::Ptr{YYJSONVal}, ::Type{<:Dict}) where {T<:NamedTuple}
    return (; yyjson_deser(Dict{Symbol,Any}, val_ptr)...)
end

# DictType

function yyjson_deser(::DictType, ::Type{T}, val_ptr::Ptr{YYJSONVal}, ::Type{<:Vector}) where {N,T<:AbstractSet{N}}
    return T(yyjson_deser(Vector{N}, val_ptr))
end

function yyjson_deser(::DictType, ::Type{T}, val_ptr::Ptr{YYJSONVal}, ::Type{<:Dict}) where {K,V,T<:AbstractDict{K,V}}
    iter = YYJSONObjIter()
    iter_ptr = pointer_from_objref(iter)
    yyjson_obj_iter_init(val_ptr, iter_ptr) || throw(YYJSONError("Failed to initialize object iterator."))
    dict_elements = T()
    for i in 1:yyjson_obj_size(val_ptr)
        key_ptr = yyjson_obj_iter_next(iter_ptr)
        val_ptr = yyjson_obj_iter_get_val(key_ptr)
        dict_elements[yyjson_deser(K, key_ptr)] = yyjson_deser(V, val_ptr)
    end
    return dict_elements
end

# ArrayType

function yyjson_deser(::ArrayType, ::Type{T}, val_ptr::Ptr{YYJSONVal}, ::Type{<:Vector}) where {T<:AbstractVector}
    iter = YYJSONArrIter()
    iter_ptr = pointer_from_objref(iter)
    yyjson_arr_iter_init(val_ptr, iter_ptr) || throw(YYJSONError("Failed to initialize array iterator."))
    array_elements = T(undef, yyjson_arr_size(val_ptr))
    @inbounds for i in eachindex(array_elements)
        val_ptr = yyjson_arr_iter_next(iter_ptr)
        array_elements[i] = yyjson_deser(eltype(T), val_ptr)
    end
    return array_elements
end

function yyjson_deser(::ArrayType, ::Type{T}, val_ptr::Ptr{YYJSONVal}, ::Type{<:Vector}) where {T<:Tuple}
    return if T == Tuple
        T(yyjson_deser(Vector{Any}, val_ptr))
    else
        iter = YYJSONArrIter()
        iter_ptr = pointer_from_objref(iter)
        yyjson_arr_iter_init(val_ptr, iter_ptr) || throw(YYJSONError("Failed to initialize array iterator."))
        tuple_elements = Vector{Any}(undef, fieldcount(T))
        for (i, type) in zip(eachindex(tuple_elements), fieldtypes(T))
            val_ptr = yyjson_arr_iter_next(iter_ptr)
            tuple_elements[i] = yyjson_deser(type, val_ptr)
        end
        T(tuple_elements)
    end
end

# CustomType

function yyjson_deser(::CustomType, ::Type{T}, val_ptr::Ptr{YYJSONVal}, ::Type{<:Vector}) where {T}
    iter = YYJSONArrIter()
    iter_ptr = pointer_from_objref(iter)
    yyjson_arr_iter_init(val_ptr, iter_ptr) || throw(YYJSONError("Failed to initialize array iterator."))
    type_elements = Vector{Any}(undef, fieldcount(T))

    for (i, type) in zip(eachindex(type_elements), fieldtypes(T))
        val_ptr = yyjson_arr_iter_next(iter_ptr)
        val = val_ptr == C_NULL ? Serde.nulltype(T) : yyjson_deser(T, type, val_ptr)
        type_elements[i] = Serde.isempty(T, val) ? Serde.nulltype(type) : val
    end

    return T(type_elements...)
end

function yyjson_eldeser(::Type{T}, ::Type{E}, key::Union{AbstractString,Symbol}, val_ptr::Ptr{YYJSONVal}) where {T,E}
    E isa Union && E.a isa Nothing && yyjson_eldeser(T, E.b, key, val_ptr)
    try
        return if yyjson_is_str(val_ptr) && isa(E, AbstractString)
            unsafestring(yyjson_get_str(val_ptr))
        elseif yyjson_is_raw(val_ptr) && isa(E, AbstractString)
            unsafestring(yyjson_get_raw(val_ptr))
        elseif yyjson_is_real(val_ptr) && isa(E, Number)
            yyjson_get_real(val_ptr)
        elseif yyjson_is_int(val_ptr) && isa(E, Number)
            yyjson_get_int(val_ptr)
        elseif yyjson_is_bool(val_ptr) && isa(E, Number)
            yyjson_get_bool(val_ptr)
        elseif yyjson_is_obj(val_ptr) && isa(E, AbstractDict)
            yyjson_deser(E, val_ptr)
        elseif yyjson_is_arr(val_ptr) && isa(E, AbstractVector)
            yyjson_deser(E, val_ptr) 
        else
            yyjson_deser(T, E, val_ptr)
        end
    catch e
        Serde.eldeser(T, E, key, yyjson_deser(Any, val_ptr))
    end
end

function yyjson_deser(::CustomType, ::Type{T}, obj_ptr::Ptr{YYJSONVal}, ::Type{<:Dict}) where {T}
    type_elements = Vector{Any}(undef, fieldcount(T))
    for (i, type, name) in zip(eachindex(type_elements), fieldtypes(T), fieldnames(T))
        key = Serde.custom_name(T, Val(name))
        val_ptr = yyjson_obj_get(obj_ptr, key)
        val = if val_ptr == C_NULL
            Serde.default_value(T, Val(name))
        else
            yyjson_eldeser(T, type, key, val_ptr)
        end

        type_elements[i] = if isnothing(val) || ismissing(val) || Serde.isempty(T, val)
            Serde.nulltype(type)
        else
            val
        end
    end
    return T(type_elements...)
end

#__ Deser

function bitwise_read_flag(;
    in_situ::Bool = false,
    number_as_raw::Bool = false,
    bignum_as_raw::Bool = false,
    stop_when_done::Bool = false,
    allow_comments::Bool = false,
    allow_inf_and_nan::Bool = false,
    allow_invalid_unicode::Bool = false,
    allow_trailing_commas::Bool = false,
)
    flag = YYJSON_READ_NOFLAG
    flag |= in_situ               ? YYJSON_READ_INSITU                : flag
    flag |= number_as_raw         ? YYJSON_READ_NUMBER_AS_RAW         : flag
    flag |= bignum_as_raw         ? YYJSON_READ_BIGNUM_AS_RAW         : flag
    flag |= stop_when_done        ? YYJSON_READ_STOP_WHEN_DONE        : flag
    flag |= allow_comments        ? YYJSON_READ_ALLOW_COMMENTS        : flag
    flag |= allow_inf_and_nan     ? YYJSON_READ_ALLOW_INF_AND_NAN     : flag
    flag |= allow_invalid_unicode ? YYJSON_READ_ALLOW_INVALID_UNICODE : flag
    flag |= allow_trailing_commas ? YYJSON_READ_ALLOW_TRAILING_COMMAS : flag
    return flag
end

function read_json_doc(json::AbstractString; kw...)
    err = YYJSONReadErr()
    doc_ptr = yyjson_read_opts(
        json,
        ncodeunits(json),
        bitwise_read_flag(; kw...),
        C_NULL,
        pointer_from_objref(err),
    )
    if doc_ptr == C_NULL
        yyjson_doc_free(doc_ptr)
        throw(err)
    end
    return doc_ptr
end

"""
    deser_json(::Type{T}, x; kw...) -> T

Creates a new object of type `T` and fill it with values from JSON formated string `x` (or vector of UInt8).

Keyword arguments `kw` is the same as in [`parse_json`](@ref Serde.ParJson.parse_json).

## Examples
```julia-repl
julia> struct Record
           count::Float64
       end

julia> struct Data
           id::Int64
           name::String
           body::Record
       end

julia> json = \"\"\" {"body":{"count":100.0},"name":"json","id":100} \"\"\";

julia> deser_json(Data, json)
Data(100, "json", Record(100.0))
```
"""
function deser_json(
    ::Type{T},
    json::AbstractString;
    kw...
) where {T}
    doc_ptr = read_json_doc(json; kw...)
    try
        return yyjson_deser(
            T,
            yyjson_doc_get_root(doc_ptr),
        )
    finally
        yyjson_doc_free(doc_ptr)
    end
end

deser_json(::Type{Nothing}, _) = nothing
deser_json(::Type{Missing}, _) = missing

function deser_json(::Type{T}, json::AbstractVector{UInt8}; kw...) where {T}
    return deser_json(T, unsafe_string(pointer(json), length(json)); kw...)
end

end
