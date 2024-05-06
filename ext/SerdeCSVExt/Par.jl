module ParCsv

using CSV
import Serde

Base.show(io::IO, e::Serde.CSV.CSVSyntaxError) = print(io, e.message)

function Serde.parse(ext::Val{:CSV}, x::Vector{UInt8}; delimiter::AbstractString = ",", kw...)
    return Serde.parse(ext, unsafe_string(pointer(x), length(x)); delimiter = delimiter, kw...)
end

function Serde.parse(::Val{:CSV}, x::S; delimiter::AbstractString = ",", kw...) where {S<:AbstractString}
    try
        return CSV.File(IOBuffer(x); delim = delimiter, types = String, strict = true, kw...) |> CSV.rowtable
    catch e
        throw(Serde.CSV.CSVSyntaxError("invalid CSV syntax", e))
    end
end

end
