module SerdeCsv

import CSV

export parse_csv, from_csv, try_from_csv, to_csv

import ..ParseError, ..SerdeError, ..to_deser, ..DefaultStrategy
import ..ser_name, ..ser_value, ..ser_type, ..ser_skip
import ..isnull, ..ClassType, ..StructClass

"""
    parse_csv(x::Union{AbstractString, Vector{UInt8}}; delimiter = ",", kw...) -> Vector{NamedTuple}

Parse a CSV string or byte vector into a vector of `NamedTuple`s without mapping to a target type.

All values are returned as `String`; conversion to numeric types is performed later by
[`from_csv`](@ref) / [`Serde.deser`](@ref).

# Arguments
- `x`: CSV text as a `String` or `Vector{UInt8}`.

# Keyword arguments
- `delimiter::AbstractString = ","`: field separator.
- Additional keyword arguments are forwarded to `CSV.File`.

# Returns
A `Vector` of `NamedTuple`s (one per data row), with keys from the header row.

# Throws
- [`ParseError`](@ref): if `x` is not valid CSV.

# Examples
```julia
julia> parse_csv("name,age\\nAlice,30\\nBob,25")
2-element Vector{NamedTuple}:
 (name = "Alice", age = "30")
 (name = "Bob",   age = "25")
```

See also: [`from_csv`](@ref), [`try_from_csv`](@ref).
"""
function parse_csv end

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

"""
    from_csv(::Type{T}, x; kw...) -> Vector{T}
    from_csv(strategy, ::Type{T}, x; kw...) -> Vector{T}
    from_csv(f::Function, x; kw...) -> Any

Parse a CSV string and deserialize each row into type `T`, returning a `Vector{T}`.

Each CSV row is deserialized independently using the column headers as field names.
All values start as strings; the deserialization engine applies type coercion for each field.

Pass a context object `strategy` (e.g. [`CamelCase()`](@ref)) to apply global field-renaming.

# Arguments
- `::Type{T}`: target struct type per row.
- `x`: CSV text as `String` or `Vector{UInt8}`.
- `strategy`: optional context object.

# Keyword arguments
- `delimiter::AbstractString = ","`: field separator forwarded to `parse_csv`.

# Returns
`Vector{T}` — one element per data row.

# Throws
- [`ParseError`](@ref): if `x` is malformed CSV.
- [`MissingFieldError`](@ref): if a required struct field is absent.
- [`TypeMismatchError`](@ref): if a column value cannot be coerced to the field type.

# Examples
```julia
julia> struct Person; name::String; age::Int; end

julia> from_csv(Person, "name,age\\nAlice,30\\nBob,25")
2-element Vector{Person}:
 Person("Alice", 30)
 Person("Bob", 25)
```

See also: [`try_from_csv`](@ref), [`to_csv`](@ref), [`parse_csv`](@ref).
"""
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

"""
    try_from_csv(::Type{T}, x; kw...) -> Union{Vector{T}, SerdeError}
    try_from_csv(strategy, ::Type{T}, x; kw...) -> Union{Vector{T}, SerdeError}

Like [`from_csv`](@ref) but returns a [`SerdeError`](@ref) instead of throwing on failure.

# Returns
- `Vector{T}` on success.
- A [`ParseError`](@ref) or [`DeserError`](@ref) subtype on failure.

See also: [`from_csv`](@ref), [`SerdeError`](@ref).
"""
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

function _csv_flat_columns(strategy, ::Type{T}; delimiter::String = "_", prefix::String = "") where {T}
    cols = String[]
    for (i, field) in enumerate(fieldnames(T))
        ser_skip(strategy, T, Val(field)) && continue
        name = string(ser_name(strategy, T, Val(field)))
        full = isempty(prefix) ? name : prefix * delimiter * name
        ft = fieldtype(T, i)
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

function _csv_write_row!(io::IO, strategy, data::T, delim::String, written::Int)::Int where {T}
    N = fieldcount(T)
    Base.@nexprs 32 i -> begin
        if i <= N
            fn_i = fieldnames(T)[i]
            if !ser_skip(strategy, T, Val(fn_i))
                v_i = ser_type(strategy, T, ser_value(strategy, T, Val(fn_i), getfield(data, fn_i)))
                if _csv_is_nested(v_i)
                    written = _csv_write_row!(io, strategy, v_i, delim, written)
                else
                    written > 0 && write(io, delim)
                    isnull(v_i) || _csv_escape!(io, string(v_i), delim)
                    written += 1
                end
            end
        end
    end
    if N > 32
        for field in fieldnames(T)[33:end]
            ser_skip(strategy, T, Val(field)) && continue
            v = ser_type(strategy, T, ser_value(strategy, T, Val(field), getfield(data, field)))
            if _csv_is_nested(v)
                written = _csv_write_row!(io, strategy, v, delim, written)
            else
                written > 0 && write(io, delim)
                isnull(v) || _csv_escape!(io, string(v), delim)
                written += 1
            end
        end
    end
    return written
end

function _csv_collect_values!(strategy, vals::Vector{Any}, data::T, idx::Int)::Int where {T}
    N = fieldcount(T)
    Base.@nexprs 32 i -> begin
        if i <= N
            fn_i = fieldnames(T)[i]
            if !ser_skip(strategy, T, Val(fn_i))
                v_i = ser_type(strategy, T, ser_value(strategy, T, Val(fn_i), getfield(data, fn_i)))
                if _csv_is_nested(v_i)
                    idx = _csv_collect_values!(strategy, vals, v_i, idx)
                else
                    vals[idx] = v_i
                    idx += 1
                end
            end
        end
    end
    if N > 32
        for field in fieldnames(T)[33:end]
            ser_skip(strategy, T, Val(field)) && continue
            v = ser_type(strategy, T, ser_value(strategy, T, Val(field), getfield(data, field)))
            if _csv_is_nested(v)
                idx = _csv_collect_values!(strategy, vals, v, idx)
            else
                vals[idx] = v
                idx += 1
            end
        end
    end
    return idx
end

# ── Context-aware serialization ──

"""
    to_csv(data::Vector{T}; delimiter = ",", headers = String[], with_names = true) -> String
    to_csv(strategy, data::Vector{T}; delimiter = ",", headers = String[], with_names = true) -> String

Serialize a vector of structs into a CSV string.

The column headers are derived from the struct field names via [`Serde.ser_name`](@ref).
Nested structs are flattened using `_` as a separator (e.g. `address_city`). Null values
(`nothing`, `missing`) are written as empty cells.

Pass a context object `strategy` (e.g. [`CamelCase()`](@ref)) as the first argument to apply
global field-renaming to the column headers.

# Arguments
- `data::Vector{T}`: the rows to serialize.
- `strategy`: optional context object.

# Keyword arguments
- `delimiter::String = ","`: field separator character.
- `headers::Vector{String} = String[]`: explicit column order. When empty, all columns
  are included in field-declaration order.
- `with_names::Bool = true`: include a header row as the first line.

# Returns
A CSV-formatted `String`. Returns `""` if `data` is empty.

# Examples
```julia
julia> struct Person; name::String; age::Int; end

julia> to_csv([Person("Alice", 30), Person("Bob", 25)]) |> print
name,age
Alice,30
Bob,25

julia> to_csv([Person("Alice", 30)]; with_names=false) |> print
Alice,30
```

See also: [`from_csv`](@ref).
"""
function to_csv(
    strategy,
    data::Vector{T};
    delimiter::String = ",",
    headers::Vector{String} = String[],
    with_names::Bool = true,
)::String where {T}
    isempty(data) && return ""

    all_cols = _csv_flat_columns(strategy, T)
    use_custom = !isempty(headers)
    out_cols = use_custom ? headers : all_cols

    io = IOBuffer(; sizehint = length(data) * length(out_cols) * 16)
    try
        if with_names
            for (i, col) in enumerate(out_cols)
                i > 1 && write(io, delimiter)
                write(io, col)
            end
            write(io, '\n')
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
                write(io, '\n')
            end
        else
            for item in data
                _csv_write_row!(io, strategy, item, delimiter, 0)
                write(io, '\n')
            end
        end

        return String(take!(io))
    finally
        close(io)
    end
end

to_csv(data::Vector{T}; kw...) where {T} = to_csv(DefaultStrategy(), data; kw...)

end
