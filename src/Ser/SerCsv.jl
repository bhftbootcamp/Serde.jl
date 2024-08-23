module SerCsv

export to_csv

import ..to_flatten, ..issimple

const WRAPPED = Set{Char}(['"', ',', ';', '\n'])

function wrap_value(s::AbstractString)
    if any(c -> c in WRAPPED, s)
        escaped_s = replace(s, "\"" => "\"\"")
        return "\"$escaped_s\""
    end
    return s
end

function to_keys(
    data::AbstractDict{K,V};
    delimiter::AbstractString = "_",
) where {K,V}
    result = String[]
    for (key, value) in data
        if isa(value, AbstractDict)
            for k in to_keys(value; delimiter = delimiter)
                push!(result, string(key) * delimiter * k)
            end
        else
            push!(result, string(key))
        end
    end
    return result
end

function to_keys(
    data::T;
    delimiter::AbstractString = "_",
) where {T}
    result = String[]
    for key in fieldnames(T)
        value = getproperty(data, key)
        if !issimple(value)
            for k in to_keys(value; delimiter = delimiter)
                push!(result, string(key) * delimiter * k)
            end
        else
            push!(result, string(key))
        end
    end
    return result
end

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

Converting a vector of custom structures.

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
str,val
a,1
b,2
```
"""
function to_csv(
    data::Vector{T};
    delimiter::String = ",",
    headers::Vector{String} = String[],
    with_names::Bool = true,
)::String where {T}
    out_data = Vector{Dict{String,Any}}(undef, length(data) + with_names)
    uni_keys = Set{String}()
    ord_keys = String[]

    for (index, item) in enumerate(data)
        flt_data = to_flatten(item)
        new_keys = setdiff(keys(flt_data), uni_keys)
        if !isempty(new_keys)
            union!(uni_keys, new_keys)
            append!(ord_keys, setdiff(to_keys(item), ord_keys))
        end
        out_data[index + with_names] = flt_data
    end

    if with_names
        out_data[1] = Dict{String,String}(ord_keys .=> ord_keys)
    end

    out_cols = isempty(headers) ? ord_keys : headers
    out_bufs = IOBuffer()
    last_col = out_cols[end]

    try
        for item in out_data
            for col in out_cols
                val = get(item, col, nothing)
                str = val === nothing ? "" : wrap_value(string(val))
                print(out_bufs, str, col != last_col ? delimiter : "\n")
            end
        end
        return String(take!(out_bufs))
    finally
        close(out_bufs)
    end
end

end