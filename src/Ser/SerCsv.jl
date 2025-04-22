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
- `include_headers::Bool = true`: determines if column headers are included in the CSV output.
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
    include_headers::Bool = true,
)::String where {T}
    comp_keys, headers = compkeys_and_headers(T, headers)

    io = IOBuffer()
    temp_buff = IOBuffer()

    include_headers && print_csv_headers(io, temp_buff, headers, delimiter)

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
    include_headers::Bool = true,
)::String
    flattened_data, headers = flattened_data_and_headers(data, headers)

    io = IOBuffer()

    include_headers && print_csv_headers(io, headers, delimiter)

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
    print(io, string_quoted(first(headers), delimiter))

    for i in eachindex(headers)[2:end]
        print(io, delimiter, string_quoted(headers[i], delimiter))
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
    print(io, string_quoted(val, delimiter))

    for i in eachindex(headers)[2:end]
        val = get(item, headers[i], nothing)
        print(io, delimiter, string_quoted(val, delimiter))
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

function string_quoted(x, delimiter::AbstractChar)
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

function flattened_data_and_headers(
    data::AbstractVector{<:AbstractDict},
    custom_headers::AbstractVector{<:AbstractString},
)
    flattened_data = to_flatten.(data)
    all_headers = unique(Iterators.flatten(keys.(flattened_data))) |> sort
    headers = isempty(custom_headers) ? all_headers : custom_headers

    return (flattened_data, headers)
end

function compkeys_and_headers(
    ::Type{T},
    custom_headers::AbstractVector{<:AbstractString},
) where {T}
    all_comp_keys = composite_keys(T)
    all_headers = [join(string.(key), '_') for key in all_comp_keys]

    if isempty(custom_headers)
        return (Tuple(all_comp_keys), all_headers)
    end

    comp_keys = Tuple[]
    headers = custom_headers
    headers_idxs_map = Dict(header => i for (i, header) in enumerate(all_headers))

    for header in headers
        idx = get(headers_idxs_map, header, nothing)
        isnothing(idx) && throw(ArgumentError("invalid header name: $(header)"))
        push!(comp_keys, all_comp_keys[idx])
    end

    return (Tuple(comp_keys), headers)
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
