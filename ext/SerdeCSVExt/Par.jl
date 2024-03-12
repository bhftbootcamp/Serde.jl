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

function parse_csv(x::Vector{UInt8}; delimiter::AbstractString = ",", kw...)
    return parse_csv(unsafe_string(pointer(x), length(x)); delimiter = delimiter, kw...)
end

function parse_csv(x::S; delimiter::AbstractString = ",", kw...) where {S<:AbstractString}
    try
        return CSV.File(IOBuffer(x); delim = delimiter, types = String, strict = true, kw...) |> CSV.rowtable
    catch e
        throw(CSVSyntaxError("invalid CSV syntax", e))
    end
end

end
