# De/Deser

"""
    ClassType

An abstract type used in the API for mapping Julia types to a "standard" set of common types.
For more details:
- CustomType
- NullType
- PrimitiveType
- ArrayType
- DictType
- NTupleType
"""
abstract type ClassType end

struct CustomType <: ClassType end
struct NullType <: ClassType end
struct PrimitiveType <: ClassType end
struct ArrayType <: ClassType end
struct DictType <: ClassType end
struct NTupleType <: ClassType end

ClassType(::T) where {T} = ClassType(T)

# CustomType

ClassType(::Type{T}) where {T<:Any} = CustomType()

# ExcludeType

ClassType(::Type{T}) where {T<:Function} = throw("non-deserializable type")

# PrimitiveType

ClassType(::Type{T}) where {T<:AbstractString} = PrimitiveType()
ClassType(::Type{T}) where {T<:AbstractChar} = PrimitiveType()
ClassType(::Type{T}) where {T<:Number} = PrimitiveType()
ClassType(::Type{T}) where {T<:Enum} = PrimitiveType()
ClassType(::Type{T}) where {T<:Symbol} = PrimitiveType()

# Null

ClassType(::Type{T}) where {T<:Nothing} = NullType()
ClassType(::Type{T}) where {T<:Missing} = NullType()

# ArrayType

ClassType(::Type{T}) where {T<:AbstractArray} = ArrayType()
ClassType(::Type{T}) where {T<:Tuple} = ArrayType()

# DictType

ClassType(::Type{T}) where {T<:AbstractDict} = DictType()
ClassType(::Type{T}) where {T<:AbstractSet} = DictType()
ClassType(::Type{T}) where {T<:Pair} = DictType()

# NTupleType

ClassType(::Type{T}) where {T<:NamedTuple} = NTupleType()

# deser type

"""
    Serde.deser(::Type{T}, data) -> T

Main function of this module which can construct an object of type `T` from another object `data`.
Can deserialize complex object with a deep nesting.

Function `deser` supports:
- Deserialization from `Dict` and `Vector` to `Struct`
- Deserialization from `Dict` and `Vector` to Vector of `Struct`
- Deserialization from `Dict` to `Dict`
- Typecasting during deserialization
- Default value for struct arguments (see [`Serde.default_value`](@ref))
- Custom name for struct arguments (see [`Serde.custom_name`](@ref))
- Empty type definition (see [`Serde.isempty`](@ref))
- Deserializing `missing` and `nothing` (see [`Serde.nulltype`](@ref))

## Examples:

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

julia> Serde.deser(Person, person_data)
Person("Michael", 25, Info(12, 2500))
```
"""
deser(::Type, ::Any)

"""
    Serde.deser(::Type{T}, ::Type{E}, data::D) -> E

Internal function that is used to deserialize `data` to fields with type `E` of custom type `T`.
Supports user overriding for custom types.

!!! note
    This function is not used explicitly and can only be overridden for the deserialization process.

## Examples:

Let's make a custom type `Order` with fields `price` and `date`.
```julia
using Dates

struct Order
    price::Int64
    date::DateTime
end
```
Now, we define a new method `Serde.deser` for the custom type `Order`.
This method will be called for each field of `Order` that is of type `DateTime` and has been passed a `String` value.
```julia
function Serde.deser(
    ::Type{T},
    ::Type{E},
    x::String
)::E where {T<:Order,E<:DateTime}
    return DateTime(x)
end
```
After that, if we try to deserialize a dictionary that has a key `date` with a `String` value, it will correctly convert the `String` to a `DateTime` value.
```julia-repl
julia> Serde.deser(Order, Dict("price" => 1000, "date" => "2024-01-01T10:20:30"))
Order(1000, DateTime("2024-01-01T10:20:30"))
```
"""
deser(::Type, ::Type, ::Any)

function deser(
    ::Type{StructType},
    ::Type{Union{Nothing,ElType}},
    data::D,
) where {StructType<:Any,ElType<:Any,D<:Any}
    return deser(StructType, ElType, data)
end

function deser(
    ::Type{StructType},
    ::Type{ElType},
    data::D,
) where {StructType<:Any,ElType<:Any,D<:Any}
    return deser(ElType, data)
end

function deser(::Type{StructType}, ::Type{Nothing}, data::D) where {StructType<:Any,D<:Any}
    return deser(Nothing, data)
end

function deser(::Type{T}, data::D) where {T<:Any,D<:Any}
    return deser(ClassType(T), T, data)
end

function deser(::Type{Union{Nothing,T}}, data::D)::T where {T<:Any,D<:Any}
    return deser(T, data)
end

function deser(::Type{Union{Missing,T}}, data::D)::T where {T<:Any,D<:Any}
    return deser(T, data)
end

function deser(::PrimitiveType, ::Type{T}, data::T)::T where {T<:Any}
    return data
end

# to Symbol

function deser(::PrimitiveType, ::Type{T}, data::D)::T where {T<:Symbol,D<:AbstractString}
    return Symbol(data)
end

# to Numbers

function deser(::PrimitiveType, ::Type{T}, data::D)::T where {T<:Number,D<:AbstractString}
    return tryparse(T, data)
end

function deser(::PrimitiveType, ::Type{T}, data::D)::T where {T<:Number,D<:Number}
    return T(data)
end

# to AbstractFloat

function deser(::PrimitiveType, ::Type{T}, data::D)::T where {T<:AbstractFloat,D<:Integer}
    return data
end

# to Enum

function deser(h::PrimitiveType, ::Type{T}, data::D)::T where {T<:Enum,D<:AbstractString}
    n = tryparse(Int64, data)
    if isnothing(n)
        deser(h, T, Symbol(data))
    else
        deser(h, T, n)
    end
end

function deser(::PrimitiveType, ::Type{T}, data::D)::T where {T<:Enum,D<:Integer}
    return T(data)
end

function deser(::PrimitiveType, ::Type{T}, data::D)::T where {T<:Enum,D<:Symbol}
    for (index, name) in Base.Enums.namemap(T)
        if name === data
            return T(index)
        end
    end
    return nothing
end

# to String

function deser(
    ::PrimitiveType,
    ::Type{T},
    data::D,
)::T where {T<:AbstractString,D<:AbstractString}
    return T(data)
end

function deser(::PrimitiveType, ::Type{T}, data::D)::T where {T<:AbstractString,D<:Symbol}
    return string(data)
end

function deser(::PrimitiveType, ::Type{T}, data::D)::T where {T<:AbstractString,D<:Number}
    return string(data)
end

# to NullType

function deser(::Type{T}, data::D)::T where {T<:Nothing,D<:Any}
    return throw(MethodError(deser, (T, data)))
end

function deser(::Type{T}, data::D)::T where {T<:Missing,D<:Any}
    return throw(MethodError(deser, (T, data)))
end

function deser(::NullType, ::Type{T}, data::D)::Nothing where {T<:Nothing,D<:Nothing}
    return nothing
end

function deser(::NullType, ::Type{T}, data::D)::Missing where {T<:Missing,D<:Nothing}
    return missing
end

# NTupleType

function deser(
    ::NTupleType,
    ::Type{D},
    data::AbstractDict{K,V},
)::D where {D<:NamedTuple,K<:Any,V<:Any}
    out::Dict{Symbol,V} = Dict{Symbol,V}()

    for (k, v) in data
        out[Symbol(k)] = v
    end

    return (; out...)
end

# DictType

function deser(
    ::DictType,
    ::Type{T},
    data::AbstractArray{D},
)::T where {N<:Any,T<:AbstractSet{N},D<:Any}
    return T(deser(Vector{N}, data))
end

function deser(::DictType, ::Type{T}, data::Tuple)::T where {T<:AbstractSet}
    return T(data)
end

function deser(
    ::DictType,
    ::Type{D},
    data::AbstractDict{K,V},
)::D where {D<:AbstractDict,K<:Any,V<:Any}
    out::D = D()

    for (k, v) in data
        try
            out[deser(keytype(out), k)] = deser(valtype(out), v)
        catch e
            if (e isa MethodError)
                throw(WrongType(D, k, v, typeof(v), valtype(out)))
            else
                rethrow(e)
            end
        end
    end

    return out
end

# ArrayType

function deser(
    ::ArrayType,
    ::Type{T},
    data::D,
)::T where {T<:AbstractVector{R} where {R<:Any},D<:AbstractVector{R} where {R<:Any}}
    return map(x -> deser(eltype(T), x), data)
end

"""
    Serde.custom_name(::Type{T}, ::Val{x}) -> x

This function is used to define an alias name for field `x` of type `T`.
Supports user overriding for custom types.
Initially, all passed names must be equivalent to the target names.
Methods of this function must return a `Symbol` or a `String` value.

!!! note
    This function is not used explicitly and can only be overridden for the deserialization process.

## Examples:

Let's make a custom type `Phone` with one field `price`.
```julia
struct Phone
    price::Int64
end
```
Now, we can define a new method `Serde.custom_name` for the type `Phone` and its field `price`.
```julia
function Serde.custom_name(::Type{Phone}, ::Val{:price})
    return "cost"
end
```
After that, if we try to deserialize a dictionary with an alias key `"cost"`, it will match with the field `price` of type `Phone`.
```julia-repl
julia> Serde.deser(Phone, Dict("cost" => 1000))
Phone(1000)
```
"""
function custom_name(::Type{T}, ::Val{x})::Symbol where {T<:Any,x}
    return x
end

"""
    Serde.default_value(::Type{T}, ::Val{x}) -> nothing

This function is used to define default values for field `x` of type `T`.
Supports user overriding for custom types.
Initially, all values are set to `nothing`.

!!! note
    This function is not used explicitly and can only be overridden for the deserialization process.

See also [`Serde.isempty`](@ref), [`Serde.nulltype`](@ref).

## Examples:
Let's make a custom type `TimeZone` with the field `gmt`.
```julia
struct TimeZone
    gmt::String
end
```
Now, we can define a new method `Serde.default_value` for the type `TimeZone` and its field `gmt`.
```julia
function Serde.default_value(::Type{TimeZone}, ::Val{:gmt})
    return "UTC+3"
end
```
After that, if we try to deserialize a dictionary without a key `gmt`, it will be filled with the default value `"UTC+3"`.
```julia-repl
julia> Serde.deser(TimeZone, Dict{String,Any}())
TimeZone("UTC+3")
```
"""
function default_value(::Type{T}, ::Val{x})::Nothing where {T<:Any,x}
    return nothing
end

"""
    Serde.isempty(::Type{T}, x) -> false

This function determines the condition under which the passed value `x` for some custom type `T` can be treated as `nothing`.
Supports user overriding for custom types.
Initially, all values are set to `false`.

!!! note
    This function is not used explicitly and can only be overridden for the deserialization process.

See also [`Serde.nulltype`](@ref), [`Serde.default_value`](@ref).

## Examples:

Let's make a custom type `Computer` with the following fields. The `gpu` field may be either a `String` or `Nothing`.
```julia
struct Computer
    cpu::String
    ram::Int64
    gpu::Union{Nothing,String}
end
```
Now, we define a new method `Serde.isempty` for the custom type `Computer`.
This method will be called for each field of `Computer` that has been passed a `String` value.
```julia
function Serde.isempty(::Type{Computer}, x::String)
    return x == ""
end
```
So, if we try to deserialize a dictionary with a key `gpu` containing an empty string, it will set a `nothing` value for such a field in `Computer`.
```julia-repl
julia> Serde.deser(Computer, Dict("cpu" => "i7-12900", "ram" => 32, "gpu" => "rtx-4090"))
Computer("i7-12900", 32, "rtx-4090")

julia> Serde.deser(Computer, Dict("cpu" => "i3-12100", "ram" => 16, "gpu" => ""))
Computer("i3-12100", 16, nothing)
```
"""
function Base.isempty(::Type{T}, x)::Bool where {T}
    return false
end

"""
    Serde.nulltype(::Type{T}) -> nothing

Defines behavior when the value for a field of type `T` is empty (according to [`Serde.isempty`](@ref)) or not specified.
Supports user overriding for custom types.
Initially, for all types, it is set to `nothing` (in case of type `Missing`, it returns the `missing` value).

!!! note
    This function is not used explicitly and can only be overridden for the deserialization process.

See also [`Serde.isempty`](@ref), [`Serde.default_value`](@ref).

## Examples
Let's make a custom type `Computer` with the following fields.
```julia
struct Computer
    cpu::String
    gpu::String
end
```
For clarity, we also define the [`Serde.isempty`](@ref) method.
```julia
Serde.isempty(::Type{Computer}, x::String) = x == ""
```
Next, we define a new method `Serde.nulltype` for the custom type `Computer`.
This method will be called for each type `String` that has been passed to a `Serde.deser` method.
```julia
Serde.nulltype(::Type{String}) = "N/A"
```
And, if we try to deserialize a dictionary with values of type `String` containing an empty string or not specified at all, it will set a `"N/A"` value for such fields in `Computer`.
```julia-repl
julia> Serde.deser(Computer, Dict("cpu" => "i7-12900", "gpu" => ""))
Computer("i7-12900", "N/A")

julia> Serde.deser(Computer, Dict{String,Any}())
Computer("N/A", "N/A")
```
"""
(nulltype(::Type{T})::Nothing) where {T<:Any} = nothing

(nulltype(::Type{Union{Nothing,T}})::Nothing) where {T<:Any} = nothing

(nulltype(::Type{Union{Missing,T}})::Missing) where {T<:Any} = missing

_field_types(::Type{T}) where {T} = Tuple(fieldtype(T, x) for x in fieldnames(T))

function deser(::CustomType, ::Type{D}, data::AbstractVector{A})::D where {D<:Any,A<:Any}
    vals = Union{_field_types(D)...}[]

    for (index, type) in enumerate(_field_types(D))
        val = get(data, index, nulltype(type))
        val = isempty(D, val) ? nulltype(type) : val
        val = !(val isa type) ? deser(D, type, val) : val
        push!(vals, val)
    end

    return D(vals...)
end

function eldeser(
    structtype::Type,
    elmtype::Type,
    key::K,
    val::V,
) where {K<:Union{AbstractString,Symbol},V<:Any}
    return try
        if val isa elmtype
            val
        else
            deser(structtype, elmtype, val)
        end
    catch e
        if isnothing(val)
            throw(ParamError("$(key)::$(elmtype)"))
        elseif (e isa MethodError) || (e isa InexactError) || (e isa ArgumentError)
            throw(WrongType(structtype, key, val, typeof(val), elmtype))
        else
            rethrow(e)
        end
    end
end

function deser(
    ::CustomType,
    ::Type{D},
    data::AbstractDict{K,V},
)::D where {D<:Any,K<:Union{AbstractString,Symbol},V<:Any}
    vals = Union{_field_types(D)...}[]

    for (type, name) in zip(_field_types(D), fieldnames(D))
        key = custom_name(D, Val(name))
        val = get(data, K(key), default_value(D, Val(name)))
        val = isnothing(val) ? nulltype(type) : val
        val = isempty(D, val) ? nulltype(type) : val
        push!(vals, eldeser(D, type, key, val))
    end

    return D(vals...)
end

function deser(::CustomType, ::Type{D}, data::N)::D where {D<:Any,N<:NamedTuple}
    vals = Union{_field_types(D)...}[]

    for (type, name) in zip(_field_types(D), fieldnames(D))
        key = custom_name(D, Val(name))
        val = get(data, key, default_value(D, Val(name)))
        val = isnothing(val) ? nulltype(type) : val
        val = isempty(D, val) ? nulltype(type) : val
        push!(vals, eldeser(D, type, key, val))
    end

    return D(vals...)
end
