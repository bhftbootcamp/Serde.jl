module DeJson

export deser_json

using YYJSON
import YYJSON: read_json_doc, open_json_doc
import ..Serde
import ..Serde: deser, eldeser, isempty, custom_name, default_value, nulltype
import ..Serde: WrongType, CustomType, NullType, PrimitiveType, ArrayType, DictType, NTupleType, ParamError
import ..to_deser

# Any

function deser(::Type{Any}, value_ptr::Ptr{YYJSONVal})
    return if yyjson_is_str(value_ptr)
        unsafe_string(yyjson_get_str(value_ptr))
    elseif yyjson_is_raw(value_ptr)
        unsafe_string(yyjson_get_raw(value_ptr))
    elseif yyjson_is_real(value_ptr)
        yyjson_get_real(value_ptr)
    elseif yyjson_is_int(value_ptr)
        yyjson_get_int(value_ptr)
    elseif yyjson_is_bool(value_ptr)
        yyjson_get_bool(value_ptr)
    elseif yyjson_is_obj(value_ptr)
        deser(Dict{String,Any}, value_ptr)
    elseif yyjson_is_arr(value_ptr)
        deser(Vector{Any}, value_ptr)
    elseif yyjson_is_null(value_ptr)
        nothing
    else
        error("Unsupported JSON type for `Any`.")
    end
end

function deser(::Type{T}, ::Type{Union{Nothing,E}}, value_ptr::Ptr{YYJSONVal}) where {T,E}
    return deser(T, E, value_ptr)
end

function deser(::Type{T}, ::Type{Nothing}, value_ptr::Ptr{YYJSONVal}) where {T}
    return deser(Nothing, value_ptr)
end

function deser(::Type{T}, ::Type{E}, value_ptr::Ptr{YYJSONVal}) where {T,E}
    return deser(E, value_ptr)
end

# PrimitiveType

function deser(::PrimitiveType, ::Type{T}, value_ptr::Ptr{YYJSONVal}) where {T<:AbstractString}
    return if yyjson_is_str(value_ptr)
        unsafe_string(yyjson_get_str(value_ptr))
    elseif yyjson_is_raw(value_ptr)
        unsafe_string(yyjson_get_raw(value_ptr))
    elseif yyjson_is_null(value_ptr)
        nothing
    else
        error("Expected a string for type `AbstractString`.")
    end
end

function deser(::PrimitiveType, ::Type{T}, value_ptr::Ptr{YYJSONVal}) where {T<:Number}
    return if yyjson_is_real(value_ptr) || yyjson_is_int(value_ptr)
        T(yyjson_get_num(value_ptr))
    elseif yyjson_is_str(value_ptr)
        tryparse(T, unsafe_string(yyjson_get_str(value_ptr)))
    elseif yyjson_is_null(value_ptr)
        nothing
    else
        error("Expected a number for type `Number`.")
    end
end

function deser(h::PrimitiveType, ::Type{T}, value_ptr::Ptr{YYJSONVal}) where {T<:Enum}
    return if yyjson_is_str(value_ptr)
        str = unsafe_string(yyjson_get_str(value_ptr))
        num = tryparse(Int64, str)
        isnothing(num) ? deser(h, T, Symbol(str)) : deser(h, T, num)
    elseif yyjson_is_raw(value_ptr)
        str = unsafe_string(yyjson_get_raw(value_ptr))
        num = tryparse(Int64, str)
        isnothing(num) ? deser(h, T, Symbol(str)) : deser(h, T, num)
    elseif yyjson_is_real(value_ptr)
        T(Int64(yyjson_get_num(value_ptr)))
    elseif yyjson_is_int(value_ptr)
        T(Int64(yyjson_get_num(value_ptr)))
    elseif yyjson_is_bool(value_ptr)
        T(Int64(yyjson_get_bool(value_ptr)))
    else
        error("Expected a string or number for type `Enum`.")
    end
end

function deser(::PrimitiveType, ::Type{T}, value_ptr::Ptr{YYJSONVal}) where {T<:Symbol}
    return if yyjson_is_str(value_ptr)
        Symbol(unsafe_string(yyjson_get_str(value_ptr)))
    elseif yyjson_is_raw(value_ptr)
        Symbol(unsafe_string(yyjson_get_raw(value_ptr)))
    elseif yyjson_is_null(value_ptr)
        nothing
    else
        error("Expected a string for type `Symbol`.")
    end
end

# NullType

function deser(::NullType, ::Type{Nothing}, value_ptr::Ptr{YYJSONVal})
    return if yyjson_is_null(value_ptr)
        nothing
    else
        error("Expected a null for type `Nothing`.")
    end
end

function deser(::NullType, ::Type{Missing}, value_ptr::Ptr{YYJSONVal})
    return if yyjson_is_null(value_ptr)
        missing
    else
        error("Expected a null for type `Missing`.")
    end
end

function deser(::NullType, ::Type{Union{Nothing,T}}, value_ptr::Ptr{YYJSONVal}) where {T}
    return if yyjson_is_null(value_ptr)
        deser(T, value_ptr)
    else
        error("Expected a null for type `Nothing`.")
    end
end

function deser(::NullType, ::Type{Union{Missing,T}}, value_ptr::Ptr{YYJSONVal}) where {T}
    return if yyjson_is_null(value_ptr)
        deser(T, value_ptr)
    else
        error("Expected a null for type `Missing`.")
    end
end

# NTupleType

function deser(::NTupleType, ::Type{T}, value_ptr::Ptr{YYJSONVal}) where {T<:NamedTuple}
    return if yyjson_is_obj(value_ptr)
        (; deser(Dict{Symbol,Any}, value_ptr)...)
    else
        error("Expected an object for type `NamedTuple`.")
    end
end

# DictType

function deser(::DictType, ::Type{T}, value_ptr::Ptr{YYJSONVal}) where {N,T<:AbstractSet{N}}
    return if yyjson_is_arr(value_ptr)
        T(deser(Vector{N}, value_ptr))
    else
        error("Expected an array for type `AbstractSet`.")
    end
end

function deser(::DictType, ::Type{T}, value_ptr::Ptr{YYJSONVal}) where {K,V,T<:AbstractDict{K,V}}
    return if yyjson_is_obj(value_ptr)
        iter = YYJSONObjIter()
        iter_ref = Ref(iter)
        iter_ptr = Base.unsafe_convert(Ptr{YYJSONObjIter}, iter_ref)
        GC.@preserve iter begin
            yyjson_obj_iter_init(value_ptr, iter_ptr) || throw(YYJSONError("Failed to initialize object iterator."))
            dict_elements = T()
            for _ = 1:yyjson_obj_size(value_ptr)
                key_ptr = yyjson_obj_iter_next(iter_ptr)
                value_ptr = yyjson_obj_iter_get_val(key_ptr)
                dict_elements[deser(K, key_ptr)] = deser(V, value_ptr)
            end
        end
        dict_elements
    else
        error("Expected an object for type `AbstractDict`.")
    end
end

# ArrayType

function deser(::ArrayType, ::Type{T}, value_ptr::Ptr{YYJSONVal}) where {T<:AbstractVector}
    return if yyjson_is_arr(value_ptr)
        iter = YYJSONArrIter()
        iter_ref = Ref(iter)
        iter_ptr = Base.unsafe_convert(Ptr{YYJSONArrIter}, iter_ref)
        GC.@preserve iter begin
            yyjson_arr_iter_init(value_ptr, iter_ptr) || throw(YYJSONError("Failed to initialize array iterator."))
            array_elements = T(undef, yyjson_arr_size(value_ptr))
            for i in eachindex(array_elements)
                elem_ptr = yyjson_arr_iter_next(iter_ptr)
                array_elements[i] = deser(eltype(T), elem_ptr)
            end
        end
        array_elements
    else
        error("Expected an array for type `AbstractVector`.")
    end
end

function deser(::ArrayType, ::Type{T}, value_ptr::Ptr{YYJSONVal}) where {T<:Tuple}
    return if yyjson_is_arr(value_ptr)
        if T == Tuple
            T(deser(Vector{Any}, value_ptr))
        else
            iter = YYJSONArrIter()
            iter_ref = Ref(iter)
            iter_ptr = Base.unsafe_convert(Ptr{YYJSONArrIter}, iter_ref)
            GC.@preserve iter begin
                yyjson_arr_iter_init(value_ptr, iter_ptr) || throw(YYJSONError("Failed to initialize array iterator."))
                tuple_elements = Vector{Any}(undef, fieldcount(T))
                for (i, type) in zip(eachindex(tuple_elements), fieldtypes(T))
                    value_ptr = yyjson_arr_iter_next(iter_ptr)
                    tuple_elements[i] = deser(type, value_ptr)
                end
            end
            T(tuple_elements)
        end
    else
        error("Expected an array for type `Tuple`.")
    end
end

# CustomType

function deser_arr(::CustomType, ::Type{T}, value_ptr::Ptr{YYJSONVal}) where {T}
    iter = YYJSONArrIter()
    iter_ref = Ref(iter)
    iter_ptr = Base.unsafe_convert(Ptr{YYJSONArrIter}, iter_ref)
    GC.@preserve iter begin
        yyjson_arr_iter_init(value_ptr, iter_ptr) || throw(YYJSONError("Failed to initialize array iterator."))
        type_elements = Vector{Any}(undef, fieldcount(T))
        for (i, field_type) in zip(eachindex(type_elements), fieldtypes(T))
            field_ptr = yyjson_arr_iter_next(iter_ptr)
            value = field_ptr == C_NULL ? nulltype(field_type) : deser(T, field_type, field_ptr)
            type_elements[i] = isempty(T, value) ? nulltype(field_type) : value
        end
        return T(type_elements...)
    end
end

@inline function typeof_yyjson_val(value_ptr::Ptr{YYJSONVal})
    return if yyjson_is_str(value_ptr)
        String
    elseif yyjson_is_raw(value_ptr)
        String
    elseif yyjson_is_real(value_ptr)
        Float64
    elseif yyjson_is_int(value_ptr)
        Int
    elseif yyjson_is_bool(value_ptr)
        Bool
    elseif yyjson_is_obj(value_ptr)
        Dict{String,Any}
    elseif yyjson_is_arr(value_ptr)
        Vector{Any}
    elseif yyjson_is_null(value_ptr)
        Nothing
    else
        Any
    end
end

@inline function issubtype(::Type{E}, ::Type{T}) where {E,T}
    return E isa Union ? any(e -> e <: T, Base.uniontypes(E)) : (E <: T)
end

function eldeser(::Type{T}, ::Type{E}, key::Union{AbstractString,Symbol}, value_ptr::Ptr{YYJSONVal}) where {T,E}
    return try
        if yyjson_is_str(value_ptr) && issubtype(E, AbstractString)
            unsafe_string(yyjson_get_str(value_ptr))
        elseif yyjson_is_raw(value_ptr) && issubtype(E, AbstractString)
            unsafe_string(yyjson_get_raw(value_ptr))
        elseif yyjson_is_real(value_ptr) && issubtype(E, Number)
            yyjson_get_real(value_ptr)
        elseif yyjson_is_int(value_ptr) && issubtype(E, Number)
            yyjson_get_int(value_ptr)
        elseif yyjson_is_bool(value_ptr) && issubtype(E, Number)
            yyjson_get_bool(value_ptr)
        elseif yyjson_is_obj(value_ptr) && issubtype(E, AbstractDict)
            deser(E, value_ptr)
        elseif yyjson_is_arr(value_ptr) && issubtype(E, AbstractVector)
            deser(E, value_ptr)
        elseif yyjson_is_null(value_ptr) && issubtype(E, Nothing)
            nothing
        elseif yyjson_is_null(value_ptr) && issubtype(E, Missing)
            missing
        else
            deser(T, E, deser(Any, value_ptr))
        end
    catch e
        value_type = typeof_yyjson_val(value_ptr)
        if yyjson_is_null(value_ptr)
            throw(ParamError("$key::$E"))
        elseif e isa MethodError || e isa InexactError || e isa ArgumentError
            throw(WrongType(T, key, "Ptr{YYJSONVal}", value_type, E))
        else
            rethrow(e)
        end
    end
end

function deser_obj(::CustomType, ::Type{T}, obj_ptr::Ptr{YYJSONVal}) where {T}
    field_values = Vector{Any}(undef, fieldcount(T))
    for (index, field_type, field_name) in zip(eachindex(field_values), fieldtypes(T), fieldnames(T))
        key = custom_name(T, Val(field_name))
        value_ptr = yyjson_obj_get(obj_ptr, key)
        value = if value_ptr == C_NULL
            default_value(T, Val(field_name))
        else
            eldeser(T, field_type, key, value_ptr)
        end
        field_values[index] = if isnothing(value) || ismissing(value) || isempty(T, value)
            nulltype(field_type)
        else
            value
        end
    end
    return T(field_values...)
end

function deser(type::CustomType, ::Type{T}, value_ptr::Ptr{YYJSONVal}) where {T}
    return if yyjson_is_arr(value_ptr)
        deser_arr(type, T, value_ptr)
    elseif yyjson_is_obj(value_ptr)
        deser_obj(type, T, value_ptr)
    else
        error("Expected an array or object.")
    end
end

#__ Deser

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
function deser_json(::Type{T}, x::AbstractString; kw...) where {T}
    doc_ptr = read_json_doc(x; kw...)
    try
        return deser(T, yyjson_doc_get_root(doc_ptr))
    finally
        yyjson_doc_free(doc_ptr)
    end
end

function deser_json(::Type{T}, json::AbstractVector{UInt8}; kw...) where {T}
    return deser_json(T, unsafe_string(pointer(json), length(json)); kw...)
end

deser_json(::Type{Nothing}, ::AbstractVector{UInt8}) = nothing
deser_json(::Type{Nothing}, ::AbstractString) = nothing
deser_json(::Type{Missing}, ::AbstractVector{UInt8}) = missing
deser_json(::Type{Missing}, ::AbstractString) = missing

function deser_json(f::Function, x; kw...)
    object = Serde.parse_json(x; kw...)
    return to_deser(f(object), object)
end

end
