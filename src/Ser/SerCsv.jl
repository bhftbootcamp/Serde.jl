module SerCsv

export to_csv

using Dates

import ..to_flatten

issimple(::Any)::Bool = false
issimple(::AbstractString)::Bool = true
issimple(::Symbol)::Bool = true
issimple(::AbstractChar)::Bool = true
issimple(::Number)::Bool = true
issimple(::Enum)::Bool = true
issimple(::Dates.TimeType)::Bool = true

issimple(t::Type) = (
    t <: AbstractString || t <: Symbol || t <: AbstractChar || t <: Number || t <: Enum || t <: Type || t <: Dates.TimeType)

isnull(t::Type) = (t === Nothing || t === Missing)
isnull(t::Any) = isnothing(t) || ismissing(t)

isunion(t::Type) = t isa Union

iscomposite(t::Type) = !issimple(t) && !isnull(t) && !isunion(t)

function is_valid_union(t::Type)::Bool
    if !isunion(t)
        return throw("Parameter `t` must be a Union type")
    end
    simple_count = 0
    composite_count = 0
    for type in Base.uniontypes(t)
        if issimple(type)
            simple_count += 1
        elseif iscomposite(type)
            composite_count += 1
        end
    end
    return simple_count + composite_count == 1
end

"""
Extract first composite type from union type, or return itself is `t` is a Union type, return nothing if no composite type.
Only type `t` is_valid_union(t) return true can be used as parameters. Otherwise, unexpected situations may occur
"""
function extract_composite(t::Type)::Union{Type,Nothing}
    if iscomposite(t)
        return t
    end
    if !isunion(t)
        throw("Parameter `t` must be a Union type or Composite Type")
    end
    try
        return first(Iterators.filter(x->iscomposite(x),Base.uniontypes(t)))
    catch
        return nothing
    end
end

function could_flatten(t::Type)::Bool
    if issimple(t)
        return false
    end
    if isnull(t)
        return false
    end
    if iscomposite(t)
        return true
    end
    if is_valid_union(t) && !isnothing(extract_composite(t))
        return true
    end
    return false
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

"Convert type value to csv cell string"
value_to_string(v::Any) = (isnothing(v) || ismissing(v)) ? "" : wrap_value(string(v))

"""
    to_csv(data::Vector{T}; kw...) -> String

Uses `data` element values to make csv rows with fieldnames as columns headers. Type `T` may be a nested dictionary or a custom type.
In case of nested `data`, names of resulting headers will be concatenate by "_" symbol using dictionary key-names or structure field names.

## Keyword arguments
- `delimiter::String = ","`: The delimiter that will be used in the returned csv string.
- `headers::Vector{String} = String[]`: Specifies which column headers will be used and in what order.
- `with_names::Bool = true`: Determines if column headers are included in the CSV output (true to include, false to exclude).
## Examples

Converting a vector of regular dictionaries with fixed headers order.

```julia-repl
jjulia> data = [
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

When using the Union type, only the following combinations are supported:

- Null Type (Nothing, Missing) + one Composite Type: `Union{Nothing, CompositeType}` or `Union{Missing, Nothing, CompositeType}`
- Null Type + one "Simple Type"(String, Symbol, Char, Number, Enum, Type, Dates.TimeType): `Union{Missing, Dates.TimeType}` 

The following Union types will not be serialized correctly:
- Union Multiple Composite Type
- Union Multiple Simple Type
- Union Simple Types + Composite Type

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

function to_csv(
    data::Vector{T};
    delimiter::String = ",",
    headers::Vector{String} = String[],
    with_names::Bool = true,
)::String where {T}
    buf = IOBuffer()
    
    # Set title if needed
    if with_names
        # Check custom headers dimensions if provided
        length(headers) > 0 ?
            (length(headers) == get_null_number(T) ?
                t_cols = headers : 
                throw(DimensionMismatch("The dimensions of custom headers do not match the dimensions of the output."))) :
            t_cols = get_headers(T)

        # write headers to buf
        join(buf,t_cols,delimiter)
        println(buf)
    end

    # Fill csv values to buf
    for e in data
        get_row_values(buf,e;delimiter = delimiter)
        println(buf)
    end

    return String(take!(buf))
end

function get_headers(type::Type)::Vector{String}
    result = Vector{String}()
    for (name,type) in zip(fieldnames(type),fieldtypes(type))
        if isunion(type) && !is_valid_union(type)
            throw("Unsupported Union Type.")
        end
        # Only `Composite type` and `Union with Composite type` could be flatten
        # - `Union with Composite type` and `Composite type`: extract Composite type from Union and recursively call get_headers.
        # - `Simple type`: push to result
        could_flatten(type) ? 
            foreach(x-> push!(result,String(name) * "_" * x), get_headers(extract_composite(type))) : push!(result,String(name))
    end
    return result
end

function get_row_values(io::IO,data::T;delimiter::String = ",") where {T}
    i = 1
    for (name,type) in zip(fieldnames(T),fieldtypes(T))
        if i != 1
            print(io, delimiter)
        end
        value = getproperty(data, name)
        could_flatten(type) ? 
            isnull(value) ? 
                print(io, repeat(delimiter,get_null_number(extract_composite(type))-1)) :
                get_row_values(io::IO,value) :
            print(io, value_to_string(value) )
        i+=1
    end
    # return result
end


function get_null_number(type::Type)::Int
    result = 0
    for type in fieldtypes(type)
        if isunion(type) && !is_valid_union(type)
            throw("Unsupported Union Type.")
        end
        result += could_flatten(type) ?  get_null_number(extract_composite(type)) : 1
    end
    return result
end

end
