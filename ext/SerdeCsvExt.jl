module SerdeCsvExt

using Serde
import CSV

import Serde: parse_csv, from_csv, try_from_csv, to_csv
import Serde: ParseError, SerdeError, to_deser, DefaultStrategy
import Serde: ser_name, ser_value, ser_type, ser_skip
import Serde: isnull, ClassType, StructClass

function parse_csv(x::Vector{UInt8}; kw...)
    return parse_csv(unsafe_string(pointer(x), length(x)); kw...)
end

function parse_csv(x::AbstractString; delimiter::AbstractString = ",", kw...)
    io = IOBuffer(x)
    try
        return CSV.File(io; delim = delimiter, types = String, strict = true, kw...) |> CSV.rowtable
    catch e
        e isa SerdeError && rethrow(e)
        throw(ParseError("CSV", "invalid CSV syntax", e))
    finally
        close(io)
    end
end

function from_csv(strategy, ::Type{T}, x; kw...) where {T}
    return to_deser(strategy, Vector{T}, parse_csv(x; kw...))
end

from_csv(::Type{T}, x; kw...) where {T} = from_csv(DefaultStrategy(), T, x; kw...)
from_csv(::Type{Nothing}, _) = nothing
from_csv(::Type{Missing}, _) = missing

function from_csv(f::Function, x; kw...)
    object = parse_csv(x; kw...)
    return to_deser(f(object), object)
end

function _try_wrap(f, args...; kw...)
    try
        return f(args...; kw...)
    catch e
        return e isa SerdeError ? e : ParseError("CSV", string(e), e)
    end
end

try_from_csv(::Type{T}, x; kw...)           where {T} = _try_wrap(from_csv, T, x; kw...)
try_from_csv(strategy, ::Type{T}, x; kw...) where {T} = _try_wrap(from_csv, strategy, T, x; kw...)

@inline function _csv_needs_quote(c::Char, delim::String)
    return c == '"' || c == '\n' || c == '\r' || (!isempty(delim) && c == delim[1])
end

function _csv_escape!(io::IO, s::AbstractString, delim::String)
    needs_quote = false
    for c in s
        if _csv_needs_quote(c, delim)
            needs_quote = true
            break
        end
    end
    if needs_quote
        write(io, UInt8('"'))
        for c in s
            c == '"' && write(io, UInt8('"'))
            write(io, c)
        end
        write(io, UInt8('"'))
    else
        write(io, s)
    end
end

@inline _csv_unwrap_nullable(::Type{T}) where {T} = T
@inline _csv_unwrap_nullable(::Type{Union{Nothing,T}}) where {T} = T
@inline _csv_unwrap_nullable(::Type{Union{Missing,T}}) where {T} = T

function _csv_flat_columns(strategy, ::Type{T}; delimiter::String = "_", prefix::String = "") where {T}
    cols = String[]
    for (i, field) in enumerate(fieldnames(T))
        ser_skip(strategy, T, Val(field)) && continue
        name = string(ser_name(strategy, T, Val(field)))
        full = isempty(prefix) ? name : prefix * delimiter * name
        ft = _csv_unwrap_nullable(fieldtype(T, i))
        if ClassType(ft) isa StructClass && fieldcount(ft) > 0
            append!(cols, _csv_flat_columns(strategy, ft; delimiter, prefix = full))
        else
            push!(cols, full)
        end
    end
    return cols
end

@inline function _csv_get_value(::Type{T}, field::Symbol, data) where {T}
    return ser_type(T, ser_value(T, Val(field), getfield(data, field)))
end

@inline function _csv_is_nested(v)
    return !isnull(v) && ClassType(v) isa StructClass && fieldcount(typeof(v)) > 0
end

# Number of leaf columns a declared field type contributes to the flattened
# CSV layout. Mirrors `_csv_flat_columns` but counts only.
@inline function _csv_field_width(strategy, ::Type{T}, ::Type{F}) where {T,F}
    Fnn = _csv_unwrap_nullable(F)
    if ClassType(Fnn) isa StructClass && fieldcount(Fnn) > 0
        n = 0
        for fn in fieldnames(Fnn)
            ser_skip(strategy, Fnn, Val(fn)) && continue
            n += _csv_field_width(strategy, Fnn, fieldtype(Fnn, findfirst(==(fn), fieldnames(Fnn))))
        end
        return n
    end
    return 1
end

function _csv_write_row!(io::IO, strategy, data::T, delim::String, written::Int, lineend::String = "\n")::Int where {T}
    N = fieldcount(T)
    for i in 1:N
        fn = fieldnames(T)[i]
        ser_skip(strategy, T, Val(fn)) && continue
        v = ser_type(strategy, T, ser_value(strategy, T, Val(fn), getfield(data, fn)))
        F = fieldtype(T, i)
        Fnn = _csv_unwrap_nullable(F)
        if ClassType(Fnn) isa StructClass && fieldcount(Fnn) > 0
            if _csv_is_nested(v)
                written = _csv_write_row!(io, strategy, v, delim, written, lineend)
            else
                w = _csv_field_width(strategy, T, F)
                for _ in 1:w
                    written > 0 && write(io, delim)
                    written += 1
                end
            end
        else
            written > 0 && write(io, delim)
            isnull(v) || _csv_escape!(io, string(v), delim)
            written += 1
        end
    end
    return written
end

function _csv_collect_values!(strategy, vals::Vector{Any}, data::T, idx::Int)::Int where {T}
    N = fieldcount(T)
    for i in 1:N
        fn = fieldnames(T)[i]
        ser_skip(strategy, T, Val(fn)) && continue
        v = ser_type(strategy, T, ser_value(strategy, T, Val(fn), getfield(data, fn)))
        F = fieldtype(T, i)
        Fnn = _csv_unwrap_nullable(F)
        if ClassType(Fnn) isa StructClass && fieldcount(Fnn) > 0
            if _csv_is_nested(v)
                idx = _csv_collect_values!(strategy, vals, v, idx)
            else
                w = _csv_field_width(strategy, T, F)
                for _ in 1:w
                    vals[idx] = nothing
                    idx += 1
                end
            end
        else
            vals[idx] = v
            idx += 1
        end
    end
    return idx
end

function to_csv(
    strategy,
    data::Vector{T};
    delimiter::String = ",",
    headers::Vector{String} = String[],
    with_names::Bool = true,
    crlf::Bool = false,
)::String where {T}
    if !(ClassType(T) isa StructClass) || fieldcount(T) == 0
        if !(T <: AbstractDict)
            throw(ArgumentError("to_csv requires Vector of structs (or Dicts), got Vector{$T}"))
        end
    end
    isempty(data) && return ""

    all_cols = _csv_flat_columns(strategy, T)
    use_custom = !isempty(headers)
    out_cols = use_custom ? headers : all_cols
    lineend = crlf ? "\r\n" : "\n"

    io = IOBuffer(; sizehint = length(data) * length(out_cols) * 16)
    try
        if with_names
            for (i, col) in enumerate(out_cols)
                i > 1 && write(io, delimiter)
                write(io, col)
            end
            write(io, lineend)
        end

        if use_custom
            col_map = Dict(name => i for (i, name) in enumerate(all_cols))
            vals = Vector{Any}(undef, length(all_cols))
            for item in data
                _csv_collect_values!(strategy, vals, item, 1)
                for (j, col) in enumerate(out_cols)
                    j > 1 && write(io, delimiter)
                    idx = get(col_map, col, 0)
                    if idx > 0
                        v = vals[idx]
                        isnull(v) || _csv_escape!(io, string(v), delimiter)
                    end
                end
                write(io, lineend)
            end
        else
            for item in data
                _csv_write_row!(io, strategy, item, delimiter, 0, lineend)
                write(io, lineend)
            end
        end

        return String(take!(io))
    finally
        close(io)
    end
end

to_csv(data::Vector{T}; kw...) where {T} = to_csv(DefaultStrategy(), data; kw...)

function to_csv(io::IO, data::Vector{T}; kw...) where {T}
    write(io, to_csv(DefaultStrategy(), data; kw...))
    return nothing
end
function to_csv(io::IO, strategy, data::Vector{T}; kw...) where {T}
    write(io, to_csv(strategy, data; kw...))
    return nothing
end

end # module
