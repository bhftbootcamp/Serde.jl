module DeCsv

using ..ParCsv
import Serde.to_deser
import Serde

function Serde.from_string(ext::Val{:CSV}, ::Type{T}, x; kw...) where {T}
    return to_deser(Vector{T}, Serde.parse(ext, x; kw...))
end

Serde.from_string(::Val{:CSV}, ::Type{Nothing}, _) = nothing
Serde.from_string(::Val{:CSV}, ::Type{Missing}, _) = missing

function Serde.from_string(ext::Val{:CSV}, f::Function, x; kw...)
    object = Serde.parse(ext, x; kw...)
    return to_deser(f(object), object)
end

end
