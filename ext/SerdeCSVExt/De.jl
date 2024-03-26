module DeCsv

using ..ParCsv
import Serde.to_deser
import Serde

function Serde.CSV.deser_csv(::Type{T}, x; kw...) where {T}
    return to_deser(Vector{T}, Serde.CSV.parse_csv(x; kw...))
end

Serde.CSV.deser_csv(::Type{Nothing}, _) = nothing
Serde.CSV.deser_csv(::Type{Missing}, _) = missing

function Serde.CSV.deser_csv(f::Function, x; kw...)
    object = Serde.CSV.parse_csv(x; kw...)
    return to_deser(f(object), object)
end

end
