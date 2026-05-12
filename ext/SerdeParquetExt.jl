module SerdeParquetExt

using Serde
using Parquet2: Parquet2, Tables

import Serde: parse_parquet, from_parquet, try_from_parquet, to_parquet
import Serde: ParseError, SerdeError, to_deser, DefaultStrategy, iter_fields
import Serde: ser_name, ser_value, ser_type, ser_skip

function parse_parquet(x::AbstractVector{UInt8};
                       dict_type::Type{D} = Dict{String,Any},
                       kw...) where {D<:AbstractDict}
    try
        ds = Parquet2.Dataset(x; kw...)
        return _parquet_rows(ds, D)
    catch e
        e isa SerdeError && rethrow(e)
        throw(ParseError("Parquet", "invalid Parquet data", e))
    end
end

function parse_parquet(io::IO; kw...)
    return parse_parquet(read(io); kw...)
end

function parse_parquet(path::AbstractString;
                       dict_type::Type{D} = Dict{String,Any},
                       kw...) where {D<:AbstractDict}
    try
        ds = Parquet2.Dataset(path; kw...)
        return _parquet_rows(ds, D)
    catch e
        e isa SerdeError && rethrow(e)
        throw(ParseError("Parquet", "invalid Parquet data", e))
    end
end

function _parquet_rows(ds, ::Type{D}) where {D<:AbstractDict}
    rows = Tables.rowtable(ds)
    return D[D(string(k) => Tables.getcolumn(row, k) for k in propertynames(row)) for row in rows]
end

# ── from_parquet: bytes / IO / path → Vector{T} ──────────────────────────────

function from_parquet(strategy, ::Type{V}, x; kw...) where {V<:AbstractVector}
    T = eltype(V)
    rows = parse_parquet(x; kw...)
    return V === Vector || T === Any ? rows : V([to_deser(strategy, T, row) for row in rows])
end

from_parquet(::Type{V}, x; kw...) where {V<:AbstractVector} =
    from_parquet(DefaultStrategy(), V, x; kw...)

function from_parquet(strategy, ::Type{T}, x; kw...) where {T}
    throw(ArgumentError(
        "from_parquet target must be a `Vector{T}` (Parquet is tabular); got $T"))
end
from_parquet(::Type{T}, x; kw...) where {T} = from_parquet(DefaultStrategy(), T, x; kw...)

# ── try_from_parquet: error-safe variant ─────────────────────────────────────

function _try_wrap(f, args...; kw...)
    try
        return f(args...; kw...)
    catch e
        return e isa SerdeError ? e : ParseError("Parquet", string(e), e)
    end
end

try_from_parquet(::Type{T}, x; kw...) where {T} =
    _try_wrap(from_parquet, T, x; kw...)
try_from_parquet(strategy, ::Type{T}, x; kw...) where {T} =
    _try_wrap(from_parquet, strategy, T, x; kw...)

# ── to_parquet: Vector{T} → bytes (or IO sink) ───────────────────────────────

function to_parquet(strategy, vals::AbstractVector; kw...)::Vector{UInt8}
    isempty(vals) && throw(ArgumentError(
        "to_parquet requires a non-empty Vector — Parquet has no zero-row encoding"))
    table = _parquet_columnar(strategy, vals)
    return Parquet2.writefile(Vector{UInt8}, table; kw...)
end

to_parquet(vals::AbstractVector; kw...) = to_parquet(DefaultStrategy(), vals; kw...)

function to_parquet(io::IO, strategy, vals::AbstractVector; kw...)
    isempty(vals) && throw(ArgumentError(
        "to_parquet requires a non-empty Vector — Parquet has no zero-row encoding"))
    table = _parquet_columnar(strategy, vals)
    Parquet2.writefile(io, table; kw...)
    return nothing
end

to_parquet(io::IO, vals::AbstractVector; kw...) =
    to_parquet(io, DefaultStrategy(), vals; kw...)

function _parquet_columnar(strategy, vals::AbstractVector{T}) where {T}
    isempty(vals) && throw(ArgumentError(
        "to_parquet: empty Vector — Parquet has no zero-row encoding"))
    RowT = isconcretetype(T) ? T : typeof(first(vals))
    fns = fieldnames(RowT)
    isempty(fns) && throw(ArgumentError(
        "to_parquet: row type $RowT has no fields"))

    n = length(vals)
    out_names = Symbol[]
    src_fields = Symbol[]
    for fn in fns
        ser_skip(strategy, RowT, Val(fn)) && continue
        push!(src_fields, fn)
        on = ser_name(strategy, RowT, Val(fn))
        push!(out_names, on isa Symbol ? on : Symbol(on))
    end
    isempty(out_names) && throw(ArgumentError(
        "to_parquet: row type $RowT has no serializable fields after `ser_skip`"))

    cols_any = [Vector{Any}(undef, n) for _ in src_fields]
    @inbounds for (i, row) in enumerate(vals)
        for j in eachindex(src_fields)
            fn = src_fields[j]
            v = ser_type(strategy, RowT,
                         ser_value(strategy, RowT, Val(fn), getfield(row, fn)))
            cols_any[j][i] = v === nothing ? missing : v
        end
    end

    cols = Any[
        _narrow_column(cols_any[j], fieldtype(RowT, src_fields[j]))
        for j in eachindex(src_fields)
    ]
    return NamedTuple{Tuple(out_names)}(Tuple(cols))
end

function _narrow_column(col::Vector{Any}, field_type::Type)
    isempty(col) && return col
    has_missing = false
    concrete = Union{}
    @inbounds for v in col
        if v === missing
            has_missing = true
        else
            concrete = Union{concrete, typeof(v)}
        end
    end
    if concrete === Union{}
        inner = _strip_null(field_type)
        return convert(Vector{Union{Missing, inner}}, col)
    end
    E = has_missing ? Union{Missing, concrete} : concrete
    return convert(Vector{E}, col)
end

@inline _strip_null(::Type{Union{Nothing, X}}) where {X} = X
@inline _strip_null(::Type{Union{Missing, X}}) where {X} = X
@inline _strip_null(::Type{Nothing}) = Any
@inline _strip_null(::Type{Missing}) = Any
@inline _strip_null(::Type{T}) where {T} = T

end # module
