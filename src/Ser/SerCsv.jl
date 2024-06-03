module SerCsv

export to_csv

import ..to_flatten

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
