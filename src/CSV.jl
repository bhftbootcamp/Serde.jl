module CSV

import ..Serde

export to_csv,
       deser_csv,
       parse_csv

function err()
    error("""CSV extension isn't loaded, please ensure that the 'CSV' package is imported
          into your environment""")
end

"""
    CSVSyntaxError <: Exception

Exception thrown when a [`parse_csv`](@ref) fails due to incorrect CSV syntax or any underlying error that occurs during parsing.

## Fields
- `message::String`: The error message.
- `exception::Exception`: The catched exception.
"""
struct CSVSyntaxError <: Exception
    message::String
    exception::Exception
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
function to_csv()
    err()
end

"""
    deser_csv(::Type{T}, x; kw...) -> Vector{T}

Creates a new object of type `T` and fill it with values from CSV formated string `x` (or vector of UInt8).

Keyword arguments `kw` is the same as in [`parse_csv`](@ref).

## Examples
```julia-repl
julia> struct Data
           id::Int64
           name::String
           grade::Float64
       end

julia> csv = \"\"\"
       "id","name","grade"
       1,"Fred",78.2
       2,"Benny",82.0
       \"\"\";

julia> deser_csv(Data, csv)
2-element Vector{Data}:
 Data(1, "Fred", 78.2)
 Data(2, "Benny", 82.0)
```
"""
function deser_csv()
    err()
end

"""
    parse_csv(x::AbstractString; kw...) -> Vector{NamedTuple}
    parse_csv(x::Vector{UInt8}; kw...) -> Vector{NamedTuple}

Parse a CSV string `x` (or vector of UInt8) into a vector of dictionaries, where keys are column names and values are corresponding cell values.

## Keyword arguments
- `delimiter::AbstractString = ","`: The delimiter that will be used in the parsed csv string.
- Other keyword arguments can be found in [`CSV.File`](https://csv.juliadata.org/stable/reading.html#CSV.File)

## Examples

```julia-repl
julia> csv = \"\"\"
       "id","name","grade"
       1,"Fred",78.2
       2,"Benny",82.0
       \"\"\";

julia> parse_csv(csv)
2-element Vector{NamedTuple{(:id, :name, :grade), Tuple{String, String, String}}}:
 (id = "1", name = "Fred", grade = "78.2")
 (id = "2", name = "Benny", grade = "82.0")
```
"""
function parse_csv() 
    err()
end

end
