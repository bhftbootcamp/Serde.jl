module DeCsv

export deser_csv

using ..ParCsv
import Serde.to_deser

function deser_csv(::Type{T}, x; kw...) where {T}
    return to_deser(Vector{T}, parse_csv(x; kw...))
end

deser_csv(::Type{Nothing}, _) = nothing
deser_csv(::Type{Missing}, _) = missing

function deser_csv(f::Function, x; kw...)
    object = parse_csv(x; kw...)
    return to_deser(f(object), object)
end

end
