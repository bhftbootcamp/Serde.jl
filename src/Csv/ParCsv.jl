module ParCsv

export CSVSyntaxError
export parse_csv

using CSV

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

Base.show(io::IO, e::CSVSyntaxError) = print(io, e.message)

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
function parse_csv end

function parse_csv(x::Vector{UInt8}; delimiter::AbstractString = ",", kw...)
    return parse_csv(unsafe_string(pointer(x), length(x)); delimiter = delimiter, kw...)
end

function parse_csv(x::S; delimiter::AbstractString = ",", kw...) where {S<:AbstractString}
    io = IOBuffer(x)
    try
        return CSV.File(io; delim = delimiter, types = String, strict = true, kw...) |> CSV.rowtable
    catch e
        throw(CSVSyntaxError("invalid CSV syntax", e))
    finally
        close(io)
    end
end

end
