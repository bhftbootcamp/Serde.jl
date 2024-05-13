module SerCsv

export to_csv

using Dates

import ..to_flatten

struct CsvSerializationError <: Exception
    message::String
end

function Base.show(io::IO, e::CsvSerializationError)
    return print(io, "CsvSerializationError: " * e.message)
end

const WRAPPED = Set{Char}(['"', ',', ';', '\n'])

function wrap_value(s::AbstractString)
    for i in eachindex(s)
        if s[i] in WRAPPED
            escaped_s = replace(s, "\"" => "\"\"")
            return "\"$escaped_s\""
        end
    end
    return s
end

const CSV_NULL = ""

value_to_string(::Nothing) = CSV_NULL
value_to_string(::Missing) = CSV_NULL
value_to_string(x::Any) = wrap_value(string(x))

issimple(::Type{<:Any})::Bool = false
issimple(::Type{<:Enum})::Bool = true
issimple(::Type{<:Symbol})::Bool = true
issimple(::Type{<:Number})::Bool = true
issimple(::Type{<:AbstractChar})::Bool = true
issimple(::Type{<:AbstractString})::Bool = true
issimple(::Type{<:Dates.TimeType})::Bool = true

isnull(::Type{Missing}) = true
isnull(::Type{Nothing}) = true
isnull(::Type{<:Any}) = false

isunion(::Type{T}) where {T} = T isa Union

iscomposite(::Type{T}) where {T} = !(issimple(T) || isnull(T) || isunion(T))

function is_valid_union(::Type{T})::Bool where {T}
    has_simple = false
    has_composite = false
    for type in Base.uniontypes(T)
        if issimple(type)
            has_simple = true
        elseif iscomposite(type)
            has_composite = true
        end
    end
    return has_simple ⊻ has_composite
end

function could_flatten(::Type{T})::Bool where {T}
    return if issimple(T)
        false
    elseif isnull(T)
        false
    elseif iscomposite(T)
        true
    elseif isunion(T)
        is_valid_union(T) && !isnothing(extract_composite(T))
    else
        false
    end
end

function extract_composite(::Type{T}) where {T}
    return if iscomposite(T)
        T
    elseif isunion(T)
        types = Base.uniontypes(T)
        index = findfirst(iscomposite, types)
        isnothing(index) ? nothing : types[index]
    else
        throw(CsvSerializationError("Parameter of type $T must be a Union type or Composite Type."))
    end
end

function null_count(::Type{T}) where {T}
    count = 0
    for type in fieldtypes(T)
        count += could_flatten(type) ?  null_count(extract_composite(type)) : 1
    end
    return count
end

function row_values(buf::IOBuffer, data::T; delimiter::String = ",") where {T}
    count = 1
    for (name, type) in zip(fieldnames(T), fieldtypes(T))
        if isunion(type) && !is_valid_union(type)
            throw(CsvSerializationError("Unsupported Union Type in field $name::$type of type $T."))
        end
        if count != 1
            print(buf, delimiter)
        end
        value = getproperty(data, name)
        if could_flatten(type)
            if isnothing(value) || ismissing(value)
                print(buf, repeat(delimiter, null_count(extract_composite(type)) - 1))
            else
                row_values(buf, value)
            end
        else
            print(buf, value_to_string(value))
        end
        count += 1
    end
end

function csv_headers(::Type{T})::Vector{String} where {T}
    headers = Vector{String}()
    for (name, type) in zip(fieldnames(T), fieldtypes(T))
        if isunion(type) && !is_valid_union(type)
            throw(CsvSerializationError("Unsupported Union Type in field $name::$type of type $T."))
        end
        if could_flatten(type)
            for header in csv_headers(extract_composite(type))
                push!(headers, String(name) * "_" * header)
            end
        else
            push!(headers, String(name))
        end
    end
    return headers
end

function to_csv(
    data::Vector{T};
    delimiter::String = ",",
    headers::Vector{String} = String[],
    with_names::Bool = true,
)::String where {T}
    buf = IOBuffer()
    
    if with_names
        t_cols = if isempty(headers)
            csv_headers(T)
        elseif length(headers) == null_count(T)
            headers
        else
            throw(DimensionMismatch("The dimensions of custom headers do not match the dimensions of the output."))
        end

        join(buf, t_cols, delimiter)
        println(buf)
    end

    for element in data
        row_values(buf, element; delimiter = delimiter)
        println(buf)
    end

    return String(take!(buf))
end

"""
    to_csv(data::Vector{T}; kw...) -> String

Uses `data` element values to make csv rows with fieldnames as columns headers. Type `T` may be a nested dictionary or a custom type.
In case of nested `data`, names of resulting headers will be concatenate by "_" symbol using dictionary key-names or structure field names.

## Keyword arguments
- `delimiter::String = ","`: The delimiter that will be used in the returned csv string.
- `headers::Vector{String} = String[]`: Specifies which column headers will be used and in what order.
- `with_names::Bool = true`: Determines if column headers are included in the CSV output (true to include, false to exclude).

!!! note
    When using the Union type, only the following combinations are supported:

    - Null Type (`Nothing`, `Missing`) with one Composite Type: `Union{Nothing, CompositeType}` or `Union{Missing, Nothing, CompositeType}`.
    - Null Type with one Simple Type (`String`, `Symbol`, `Char`, `Number`, `Enum`, `Type`, `Dates.TimeType`): `Union{Missing, Dates.TimeType}`.

    The following Union types will not be serialized correctly:
    - Union Multiple Composite Type
    - Union Multiple Simple Type
    - Union Simple Types with Composite Type

## Examples

Converting a vector of regular dictionaries with fixed headers order.

```julia-repl
julia> data = [
           Dict("id" => 1, "name" => "Jack"),
           Dict( "id" => 2, "name" => "Bob"),
       ];

julia> to_csv(data, headers = ["name", "id"]) |> print
name,id
Jack,1
Bob,2
```

Converting a vector of nested dictionaries with custom separator symbol.

```julia-repl
julia> data = [
            Dict(
                "level" => 1,
                "sub" => Dict(
                    "level" => 2,
                    "sub" => Dict(
                        "level" => 3
                    ),
                ),
            ),
            Dict(:level => 1),
       ];

julia> to_csv(data, separator = "|") |> print
level|sub_level|sub_sub_level
1|2|3
1||
```

Converting a vector of custom structures. The headers order will be consistent with the structure fields.

```julia-repl
julia> struct Foo
           val::Int64
           str::String
       end

julia> data = [Foo(1, "a"), Foo(2, "b")]
2-element Vector{Foo}:
 Foo(1, "a")
 Foo(2, "b")

julia> to_csv(data) |> print
val,str
1,a
2,b
```
"""
function to_csv(
    data::Vector{T};
    delimiter::String = ",",
    headers::Vector{String} = String[],
    with_names::Bool = true,
)::String where {T<:AbstractDict}
    cols = Set{String}()
    vals = Vector{Dict{String,Any}}(undef, length(data) + with_names)

    for (index, item) in enumerate(data)
        val = to_flatten(item)
        push!(cols, keys(val)...)
        vals[index + with_names] = val
    end

    with_names && (vals[1] = Dict{String,String}(cols .=> string.(cols)))
    t_cols = isempty(headers) ? sort([cols...]) : headers
    l_cols = t_cols[end]
    buf = IOBuffer()

    for csv_item in vals
        for col in t_cols
            val = get(csv_item, col, nothing)
            str = val === nothing ? "" : wrap_value(string(val))
            print(buf, str, col != l_cols ? delimiter : "\n")
        end
    end

    return String(take!(buf))
end

end
