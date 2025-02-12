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

struct AbstractType <: ClassType end
struct CustomType <: ClassType end
struct NullType <: ClassType end
struct PrimitiveType <: ClassType end
struct ArrayType <: ClassType end
struct DictType <: ClassType end
struct NTupleType <: ClassType end

ClassType(::T) where {T} = ClassType(T)

ClassType(::Type{T}) where {T<:Any} = CustomType()

ClassType(::Type{T}) where {T<:AbstractString} = PrimitiveType()
ClassType(::Type{T}) where {T<:AbstractChar} = PrimitiveType()
ClassType(::Type{T}) where {T<:Number} = PrimitiveType()
ClassType(::Type{T}) where {T<:Enum} = PrimitiveType()
ClassType(::Type{T}) where {T<:Symbol} = PrimitiveType()

ClassType(::Type{T}) where {T<:Nothing} = NullType()
ClassType(::Type{T}) where {T<:Missing} = NullType()

ClassType(::Type{T}) where {T<:AbstractArray} = ArrayType()
ClassType(::Type{T}) where {T<:Tuple} = ArrayType()

ClassType(::Type{T}) where {T<:AbstractDict} = DictType()
ClassType(::Type{T}) where {T<:AbstractSet} = DictType()
ClassType(::Type{T}) where {T<:Pair} = DictType()

ClassType(::Type{T}) where {T<:NamedTuple} = NTupleType()

ClassType(::Type{T}) where {T<:Function} = throw("non-deserializable type")

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

See also [`Serde.isempty`](@ref), [`Serde.nulltype`](@ref), [`Serde.isignored_name`](@ref).

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

See also [`Serde.nulltype`](@ref), [`Serde.default_value`](@ref), [`Serde.isignored_name`](@ref).

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

See also [`Serde.isempty`](@ref), [`Serde.default_value`](@ref), [`Serde.isignored_name`](@ref).

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
(nulltype(::Type{T})) where {T<:Any} = nothing
(nulltype(::Type{Missing})) = missing
(nulltype(::Type{Union{Nothing,T}})::Nothing) where {T<:Any} = nothing
(nulltype(::Type{Union{Missing,T}})::Missing) where {T<:Any} = missing

"""
    Serde.isignored_name(::Type{T}, ::Val{x}) -> false

This function allows to mark a field `x` for some custom type `T` as ignored for deserialization.
Supports user overriding for custom types.
Initially, all field names are set to `false`.

!!! note
    This function is not used explicitly and can only be overridden for the deserialization process.

See also [`Serde.nulltype`](@ref), [`Serde.default_value`](@ref), [`Serde.isempty`](@ref).

## Examples:

Let's make a custom type `Computer` with the following fields and constructor.
```julia
struct Computer
    cpu::String
    ram::Int64
    info::String
end

function Computer(cpu::String, ram::Int64)
    return Computer(cpu, ram, string("cpu: ", cpu, " ram: ", ram))
end
```
Now, we define a new method `Serde.isignored_name` for the custom type `Computer`.
This method will be called for each field of `Computer`.
```julia
function Serde.isignored_name(::Type{Computer}, ::Val{:info})
    return true
end
```
So, if we try to deserialize a dictionary with two keys into a custom type `Computer` with three fields, it will call the constructor that takes two arguments.
```julia-repl
julia> Serde.deser(Computer, Dict("cpu" => "i7-12700H", "ram" => 32))
Computer("i7-12700H", 32, "cpu: i7-12700H ram: 32")
```
"""
function isignored_name(::Type{T}, ::Val{x}) where {T<:Any, x}
    return false
end

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

(deser(::Type{T}, data::D)) where {T<:Any,D<:Any} = deser(ClassType(T), T, data)

(deser(::PrimitiveType, ::Type{T}, data::T)::T) where {T<:Any} = data
(deser(::PrimitiveType, ::Type{T}, data::D)::T) where {T<:Symbol,D<:AbstractString} = Symbol(data)
(deser(::PrimitiveType, ::Type{T}, data::D)::T) where {T<:Number,D<:AbstractString} = tryparse(T, data)
(deser(::PrimitiveType, ::Type{T}, data::D)::T) where {T<:Number,D<:Number} = T(data)
(deser(::PrimitiveType, ::Type{T}, data::D)::T) where {T<:AbstractFloat,D<:Integer} = data
(deser(::PrimitiveType, ::Type{T}, data::D)::T) where {T<:AbstractString,D<:AbstractString} = T(data)
(deser(::PrimitiveType, ::Type{T}, data::D)::T) where {T<:AbstractString,D<:Symbol} = string(data)
(deser(::PrimitiveType, ::Type{T}, data::D)::T) where {T<:AbstractString,D<:Number} = string(data)
(deser(::PrimitiveType, ::Type{T}, data::D)::T) where {T<:Enum,D<:Integer} = T(data)

function deser(::PrimitiveType, ::Type{T}, data::D)::T where {T<:Enum,D<:AbstractString}
    return deser(PrimitiveType(), T, Symbol(data))
end

function deser(::PrimitiveType, ::Type{T}, data::D)::T where {T<:Enum,D<:Symbol}
    for (index, name) in Base.Enums.namemap(T)
        name === data && return T(index)
    end
    return nothing
end

(deser(::NullType, ::Type{T}, data::D)::Nothing) where {T<:Nothing,D<:Nothing} = nothing
(deser(::NullType, ::Type{T}, data::D)::Missing) where {T<:Missing,D<:Nothing} = missing

(deser(::Type{Union{Nothing,T}}, data::D)::T) where {T<:Any,D<:Any} = deser(T, data)
(deser(::Type{Union{Missing,T}}, data::D)::T) where {T<:Any,D<:Any} = deser(T, data)

(deser(::Type{T}, ::T)::T) where {T<:Nothing} = nothing
(deser(::Type{T}, ::T)::T) where {T<:Missing} = missing

(deser(::Type{T}, ::Type{Union{Nothing,E}}, data::D)) where {T<:Any,E<:Any,D<:Any} = deser(T, E, data)
(deser(::Type{T}, ::Type{E}, data::D)) where {T<:Any,E<:Any,D<:Any} = deser(E, data)
(deser(::Type{T}, ::Type{Nothing}, data::D)) where {T<:Any,D<:Any} = deser(Nothing, data)

(deser(::Type{T}, data::D)::T) where {T<:Nothing,D<:Any} = throw(MethodError(deser, (T, data)))
(deser(::Type{T}, data::D)::T) where {T<:Missing,D<:Any} = throw(MethodError(deser, (T, data)))

function deser(::NTupleType, ::Type{T}, data::AbstractDict{K,D})::T where {T<:NamedTuple,K,D}
    target::Dict{Symbol,D} = Dict{Symbol,D}()
    for (k, v) in data
        target[Symbol(k)] = v
    end
    return (; target...)
end

function deser(::ArrayType, ::Type{T}, data::D)::T where {T<:AbstractVector{E} where {E<:Any},D<:AbstractVector{E} where {E<:Any}}
    return map(x -> deser(eltype(T), x), data)
end

function deser(::ArrayType, ::Type{T}, data::D)::T where {T<:Tuple,D<:Union{Tuple,AbstractVector}}
    return if (T === Tuple) || isa(T, UnionAll)
        T(data)
    else
        T(deser(t, v) for (t, v) in zip(fieldtypes(T), data))
    end
end

function deser(::DictType, ::Type{T}, data::AbstractArray{D})::T where {T<:AbstractSet,D}
    return T(data)
end

function deser(::DictType, ::Type{T}, data::AbstractDict{K,D})::T where {T<:AbstractDict,K,D}
    target = T()
    for (k, v) in data
        try
            target[deser(keytype(target), k)] = deser(valtype(target), v)
        catch e
            throw(e isa MethodError ? WrongType(T, k, v, typeof(v), valtype(target)) : e)
        end
    end
    return target
end

@inline function eldeser(ct::Type, ft::Type, key::K, data::D) where {K,D}
    try
        return data isa ft ? data : deser(ct, ft, data)
    catch e
        if isnothing(data)
            throw(ParamError("$(key)::$(ft)"))
        elseif e isa MethodError || e isa ArgumentError || e isa InexactError
            throw(WrongType(ct, key, data, typeof(data), ft))
        else
            rethrow(e)
        end
    end
end

function subtype_key(::Type{T}) where {T<:Any}
    error("Define `subtype_key(::Type{$T})::Union{String,Symbol}` to specify the subtype field.")
end

function subtypes(::Type{T}) where {T<:Any}
    error("Define `get_subtypes(::Type{$T})::Vector{Type}` to specify the available subtypes.")
end

function deser(::AbstractType, ::Type{T}, data::AbstractDict{K,D})::T where {T,K,D}
    key = subtype_key(T)::Union{String,Symbol}
    key_val = Symbol(data[K(key)])
    for sub in subtypes(T)
        if nameof(sub) == key_val
            return deser(CustomType(), sub, data)
        end
    end
    throw(MissingKeyError(key))
end

function deser(::CustomType, ::Type{T}, data::AbstractVector{A})::T where {T<:Any,A<:Any}
    veclen = fieldcount(T)
    target = Vector{Any}(undef, veclen)
    index::Int = 0
    for (type, name) in zip(fieldtypes(T), fieldnames(T))
        isignored_name(T, Val(name)) && continue
        index += 1
        val = get(data, index, nulltype(type))
        val = isnothing(val) || ismissing(val) || isempty(T, val) ? nulltype(type) : val
        target[index] = eldeser(T, type, name, val)
    end
    veclen != index && resize!(target, index)
    return T(target...)
end

function deser(::CustomType, ::Type{T}, data::AbstractDict{K,D})::T where {T<:Any,K<:Union{AbstractString,Symbol},D<:Any}
    veclen = fieldcount(T)
    target = Vector{Any}(undef, veclen)
    index::Int = 0
    for (type, name) in zip(fieldtypes(T), fieldnames(T))
        isignored_name(T, Val(name)) && continue
        index += 1
        key = custom_name(T, Val(name))
        key = isa(key, K) ? key : deser(K, key)
        val = get(data, key, default_value(T, Val(name)))
        val = isnothing(val) || ismissing(val) || isempty(T, val) ? nulltype(type) : val
        target[index] = eldeser(T, type, key, val)
    end
    veclen != index && resize!(target, index)
    return T(target...)
end

function deser(::CustomType, ::Type{T}, data::N)::T where {T<:Any,N<:NamedTuple}
    veclen = fieldcount(T)
    target = Vector{Any}(undef, veclen)
    index::Int = 0
    for (type, name) in zip(fieldtypes(T), fieldnames(T))
        isignored_name(T, Val(name)) && continue
        index += 1
        key = custom_name(T, Val(name))
        val = get(data, Symbol(key), default_value(T, Val(name)))
        val = isnothing(val) || ismissing(val) || isempty(T, val) ? nulltype(type) : val
        target[index] = eldeser(T, type, key, val)
    end
    veclen != index && resize!(target, index)
    return T(target...)
end
