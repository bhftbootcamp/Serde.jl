module SerCsv

export to_csv

using Dates
import ..to_flatten

const QUOTE = '"'
const WRAPPED = [QUOTE, '\n']

isatomictype(::Type{<:Any}) = false
isatomictype(::Type{<:AbstractString}) = true
isatomictype(::Type{Symbol}) = true
isatomictype(::Type{<:AbstractChar}) = true
isatomictype(::Type{<:Number}) = true
isatomictype(::Type{<:Enum}) = true
isatomictype(::Type{<:Type}) = true
isatomictype(::Type{<:Dates.TimeType}) = true

"""
    to_csv(data::AbstractVector{T}; kw...) -> String

Uses `data` element values to make csv rows with dictionary key-names or structure field names as columns headers. Type `T` may be a nested dictionary or a custom type.
In case of nested `data`, names of resulting headers will be concatenated by `'_'` symbol.

# Keyword arguments
- `delimiter::AbstractChar = ','`: the delimiter that will be used in the returned csv string.
- `headers::AbstractVector{<:AbstractString} = String[]`: specifies which column headers will be used and in what order.
- `with_names::Bool = true`: determines if column headers are included in the CSV output.
# Examples

Converting a vector of regular dictionaries with fixed headers order:

```julia-repl
julia> data = [
           Dict("id" => 1, "name" => "Jack"),
           Dict("id" => 2, "name" => "Bob"),
       ];

julia> to_csv(data, headers = ["name", "id"]) |> print
name,id
Jack,1
Bob,2
```

Converting a vector of nested dictionaries with custom delimiter symbol:

```julia-repl
julia> data = [
           Dict(
               "level" => 1,
               "sub" => Dict(
                   "level" => 2,
                   "sub" => Dict(
                       "level" => 3,
                   ),
               ),
           ),
           Dict(:level => 1),
       ];

julia> to_csv(data, delimiter = '|') |> print
level|sub_level|sub_sub_level
1|2|3
1||
```

Converting a vector of custom structures:

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
    data::AbstractVector{T};
    delimiter::AbstractChar = ',',
    headers::AbstractVector{<:AbstractString} = String[],
    with_names::Bool = true,
)::String where {T}
    comp_keys, headers = compkeys_and_headers(T, headers)

    io = IOBuffer()
    temp_buff = IOBuffer()

    with_names && print_csv_headers(io, temp_buff, headers, delimiter)

    Base.ensureroom(io, length(comp_keys) * length(data))

    for item in data
        print_csv_line(io, temp_buff, item, Val(comp_keys), delimiter)
    end

    return String(take!(io))
end

function to_csv(
    data::AbstractVector{<:AbstractDict};
    delimiter::AbstractChar = ',',
    headers::AbstractVector{<:AbstractString} = String[],
    with_names::Bool = true,
)::String
    flattened_data = to_flatten.(data)
    headers = process_headers(flattened_data, headers)

    io = IOBuffer()

    with_names && print_csv_headers(io, headers, delimiter)

    for item in flattened_data
        print_csv_line(io, item, headers, delimiter)
    end

    return String(take!(io))
end

function print_csv_headers(
    io::IOBuffer,
    headers::AbstractVector{<:AbstractString},
    delimiter::AbstractChar,
)
    print(io, quotestring(first(headers), delimiter))

    for i in eachindex(headers)[2:end]
        print(io, delimiter, quotestring(headers[i], delimiter))
    end

    println(io)
end

function print_csv_headers(
    io::IOBuffer,
    temp_buff::IOBuffer,
    headers::AbstractVector{<:AbstractString},
    delimiter::AbstractChar,
)
    print(temp_buff, first(headers))
    copyquoted(io, temp_buff, delimiter)

    for i in eachindex(headers)[2:end]
        print(io, delimiter)
        truncate(temp_buff, 0)
        print(temp_buff, headers[i])
        copyquoted(io, temp_buff, delimiter)
    end

    println(io)
end

function print_csv_line(
    io::IOBuffer,
    item::Dict{String, Any},
    headers::AbstractVector{<:AbstractString},
    delimiter::AbstractChar,
)
    val = get(item, first(headers), nothing)
    print(io, quotestring(val, delimiter))

    for i in eachindex(headers)[2:end]
        val = get(item, headers[i], nothing)
        print(io, delimiter, quotestring(val, delimiter))
    end

    println(io)
end

@generated function print_csv_line(
    io::IOBuffer,
    temp_buff::IOBuffer,
    item,
    ::Val{CK},
    delimiter::AbstractChar,
) where {CK}
    body_exprs = []

    for i in 1:length(CK)
        getprop_expr = :(item)
        for key in CK[i]
            getprop_expr = :($(getprop_expr).$(key))
        end

        push!(body_exprs,
            quote
                truncate(temp_buff, 0)
                print(temp_buff, $(getprop_expr))
                copyquoted(io, temp_buff, delimiter)
            end
        )

        if i < length(CK)
            push!(body_exprs, quote print(io, delimiter) end)
        end
    end

    push!(body_exprs, quote println(io) end)

    body = quote $(body_exprs...) end
    return body
end

function quotestring(x, delimiter::AbstractChar)
    s = isnothing(x) ? "" : string(x)
    if occursin(delimiter, s) || any(c -> c in WRAPPED, s)
        return string(QUOTE, replace(s, QUOTE => QUOTE^2), QUOTE)
    end
    return s
end

function copyquoted(dst::IOBuffer, src::IOBuffer, delimiter::AbstractChar)
    quoted = false
    quotes = 0
    seekstart(src)
    while !eof(src)
        ch = read(src, Char)
        if ch == delimiter || ch in WRAPPED
            quoted = true
        end
        if ch == QUOTE
            quotes += 1
        end
    end

    nb = position(src)
    Base.ensureroom(dst, nb + quoted * (2 + quotes))

    quoted && print(dst, QUOTE)

    seekstart(src)
    while !eof(src)
        ch = read(src, Char)
        print(dst, ch)
        ch == QUOTE && print(dst, ch)
    end

    quoted && print(dst, QUOTE)
    return
end

function compkeys_and_headers(
    ::Type{T},
    custom_headers::AbstractVector{<:AbstractString},
) where {T}
    struct_comp_keys = composite_keys(T)
    struct_headers = [join(string.(key), '_') for key in struct_comp_keys]

    if isempty(custom_headers)
        return (Tuple(struct_comp_keys), struct_headers)
    end

    comp_keys = Tuple[]
    headers_idxs_map = Dict(header => i for (i, header) in enumerate(struct_headers))

    for header in custom_headers
        idx = get(headers_idxs_map, header, nothing)
        isnothing(idx) && throw(ArgumentError("invalid header name: $(header)"))
        push!(comp_keys, struct_comp_keys[idx])
    end

    return (Tuple(comp_keys), custom_headers)
end

function process_headers(
    flattened_data::AbstractVector{<:Dict{String, Any}},
    custom_headers::AbstractVector{<:AbstractString},
)
    flattened_keys = unique(Iterators.flatten(keys.(flattened_data))) |> sort
    headers = isempty(custom_headers) ? flattened_keys : custom_headers
    return headers
end

function composite_keys(::Type{<:T}) where {T}
    res = Tuple[]
    for (key, type) in zip(fieldnames(T), fieldtypes(T))
        if isatomictype(type) || !isconcretetype(type)
            push!(res, (key,))
        else
            for subkeys in composite_keys(type)
                push!(res, (key, subkeys...))
            end
        end
    end

    return res
end

end
