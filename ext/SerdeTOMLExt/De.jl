module DeToml

using ..ParToml
import Serde.to_deser
import Serde

function Serde.from_string(ext::Val{:TOML}, ::Type{T}, x; kw...) where {T}
    return to_deser(T, Serde.parse(ext, x; kw...))
end

Serde.from_string(::Val{:TOML}, ::Type{Nothing}, _) = nothing
Serde.from_string(::Val{:TOML}, ::Type{Missing}, _) = missing

function Serde.from_string(ext::Val{:TOML}, f::Function, x; kw...)
    object = Serde.parse(ext, x; kw...)
    return to_deser(f(object), object)
end

end
