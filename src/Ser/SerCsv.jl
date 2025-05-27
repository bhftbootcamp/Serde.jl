module SerCsv

export to_csv

using Dates
import ..to_flatten
import ..rec_valtype

const QUOTE = '"'
const WRAPPED = [QUOTE, '\n']
const INVALID_DELIMITERS = [WRAPPED...]

isatomictype(::Type{T}) where {T} = isprimitivetype(T)
isatomictype(::Type{<:AbstractString}) = true
isatomictype(::Type{Symbol}) = true
isatomictype(::Type{<:AbstractChar}) = true
isatomictype(::Type{<:Number}) = true
isatomictype(::Type{<:Enum}) = true
isatomictype(::Type{<:Type}) = true
isatomictype(::Type{<:TimeType}) = true

"""
    to_csv(data::Vector{T}; kw...) -> String

Uses `data` element values to make csv rows with dictionary key-names or structure field names as columns headers. Type `T` may be a nested dictionary or a custom type.
In case of nested `data`, names of resulting headers will be concatenated by `'_'` symbol.

# Keyword arguments
- `delimiter::Union{Char,String} = ','`: the delimiter that will be used in the returned csv string.
- `headers::Vector{String} = String[]`: specifies which column headers will be used and in what order.
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
    delimiter::Union{AbstractChar,AbstractString} = ',',
    headers::AbstractVector{<:AbstractString} = String[],
    with_names::Bool = true,
) where {T}
    delimiter = parse_delimiter(delimiter)
    base_keys = composite_keys(T)
    if isempty(headers)
        selected_keys = base_keys
        headers = flattenkey.(selected_keys)
    else
        selected_keys = selectkeys(base_keys, headers)
    end

    io = IOBuffer()
    with_names && print_csv_headers(io, headers, delimiter)
    print_csv_body(io, data, Val(Tuple(selected_keys)), delimiter)

    return String(take!(io))
end

function to_csv(
    data::AbstractVector{T};
    delimiter::Union{AbstractChar,AbstractString} = ',',
    headers::AbstractVector{<:AbstractString} = String[],
    with_names::Bool = true,
) where {T<:AbstractDict}
    delimiter = parse_delimiter(delimiter)
    flattened_data = to_flatten.(Dict{String,rec_valtype(T)}, data)
    if isempty(headers)
        headers = Iterators.flatten(keys.(flattened_data)) |> unique |> sort
    end

    io = IOBuffer()
    with_names && print_csv_headers(io, headers, delimiter)
    print_csv_body(io, flattened_data, headers, delimiter)

    return String(take!(io))
end

function parse_delimiter(delimiter::Union{AbstractChar,AbstractString})
    if length(delimiter) != 1 || first(delimiter) in INVALID_DELIMITERS
        throw(ArgumentError("invalid delimiter: `$(repr(delimiter))`"))
    end
    return first(delimiter)
end

function flattenkey(composite_key, delimiter::AbstractChar = '_')
    return join((string(k) for k in composite_key), delimiter)
end

function composite_keys(::Type{T}) where {T}
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

function selectkeys(
    base_keys::AbstractVector{<:Tuple},
    custom_headers::AbstractVector{<:AbstractString},
)
    headers_to_compkeys_map = Dict(flattenkey(k) => k for k in base_keys)
    comp_keys = Tuple[]
    for header in custom_headers
        key = get(headers_to_compkeys_map, header, nothing)
        isnothing(key) && throw(ArgumentError("invalid header: `$(repr(header))`"))
        push!(comp_keys, key)
    end
    return comp_keys
end

function print_csv_headers(
    io::IOBuffer,
    headers::AbstractVector{<:AbstractString},
    delimiter::AbstractChar,
)
    temp_buff = IOBuffer()
    for i in eachindex(headers)
        print_csv_value(io, headers[i], temp_buff, delimiter)
        i < lastindex(headers) && print(io, delimiter)
    end
    println(io)
    return
end

function getcompkey_expr(item_name::Symbol, comp_key::Tuple)
    res = item_name
    for key in comp_key
        res = :($(res).$(key))
    end
    return res
end

@generated function print_csv_body(
    io::IOBuffer,
    data::AbstractVector{T},
    ::Val{CK},
    delimiter::AbstractChar,
) where {T,CK}
    print_records_exprs = []
    for i in eachindex(CK)
        value_expr = getcompkey_expr(:item, CK[i])
        push!(print_records_exprs,
            quote print_csv_value(io, $(value_expr), temp_buff, delimiter) end
        )
        if i < lastindex(CK)
            push!(print_records_exprs,
                quote print(io, delimiter) end
            )
        end
    end
    push!(print_records_exprs, quote println(io) end)

    return quote
        temp_buff = IOBuffer()
        Base.ensureroom(io, $(length(CK)) * length(data))
        for item in data
            $(print_records_exprs...)
        end
    end
end

function print_csv_body(
    io::IOBuffer,
    data::AbstractVector{<:AbstractDict{String}},
    headers::AbstractVector{<:AbstractString},
    delimiter::AbstractChar,
)
    temp_buff = IOBuffer()
    Base.ensureroom(io, length(headers) * length(data))
    for item in data
        for i in eachindex(headers)
            if headers[i] in keys(item)
                print_csv_value(io, item[headers[i]], temp_buff, delimiter)
            end
            i < lastindex(headers) && print(io, delimiter)
        end
        println(io)
    end
    return
end

function print_csv_value(
    io::IOBuffer,
    value::Any,
    temp_buff::IOBuffer,
    delimiter::AbstractChar,
)
    truncate(temp_buff, 0)
    print(temp_buff, value)
    copyquoted(io, temp_buff, delimiter)
    return
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

end
