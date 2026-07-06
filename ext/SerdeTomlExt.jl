module SerdeTomlExt

using Serde
using Dates
using UUIDs
import TOML

import Serde: parse_toml, from_toml, try_from_toml, to_toml
import Serde: ParseError, SerdeError, to_deser, DefaultStrategy
import Serde: ser_name, ser_value, ser_type, ser_skip
import Serde: isnull, issimple

function parse_toml(x::AbstractString; kw...)
    try
        TOML.parse(x; kw...)
    catch e
        throw(ParseError("TOML", "invalid TOML syntax", e))
    end
end

function parse_toml(x::Vector{UInt8}; kw...)
    return parse_toml(unsafe_string(pointer(x), length(x)); kw...)
end

function from_toml(strategy, ::Type{T}, x; kw...) where {T}
    return to_deser(strategy, T, parse_toml(x; kw...))
end

from_toml(::Type{T}, x; kw...) where {T} = from_toml(DefaultStrategy(), T, x; kw...)
from_toml(::Type{Nothing}, _) = nothing
from_toml(::Type{Missing}, _) = missing

function from_toml(f::Function, x; kw...)
    object = parse_toml(x; kw...)
    return to_deser(f(object), object)
end

function _try_wrap(f, args...; kw...)
    try
        return f(args...; kw...)
    catch e
        return e isa SerdeError ? e : ParseError("TOML", string(e), e)
    end
end

try_from_toml(::Type{T}, x; kw...)           where {T} = _try_wrap(from_toml, T, x; kw...)
try_from_toml(strategy, ::Type{T}, x; kw...) where {T} = _try_wrap(from_toml, strategy, T, x; kw...)

const TOML_DQUOTE = '"'

@inline function _toml_float_buf()
    buf = get(task_local_storage(), :_serde_toml_float_buf, nothing)
    if buf === nothing
        buf = Vector{UInt8}(undef, 32)
        task_local_storage(:_serde_toml_float_buf, buf)
    end
    return buf::Vector{UInt8}
end

@inline function _toml_write_uint!(io::IO, n::UInt64)
    n >= 10 && _toml_write_uint!(io, div(n, 10))
    write(io, UInt8('0') + rem(n, 10) % UInt8)
end

function _toml_escape_str!(io::IO, s::AbstractString)
    @inbounds for c in s
        b = Char(c)
        cp = Int(b)
        if b == '"'
            write(io, "\\\"")
        elseif b == '\\'
            write(io, "\\\\")
        elseif b == '\b'
            write(io, "\\b")
        elseif b == '\t'
            write(io, "\\t")
        elseif b == '\n'
            write(io, "\\n")
        elseif b == '\f'
            write(io, "\\f")
        elseif b == '\r'
            write(io, "\\r")
        elseif cp < 0x20 || cp == 0x7f
            write(io, "\\u")
            for shift in (12, 8, 4, 0)
                d = (cp >> shift) & 0xf
                write(io, UInt8(d < 10 ? UInt8('0') + d : UInt8('a') + d - 10))
            end
        else
            print(io, b)
        end
    end
end

_toml_value(io::IO, val::AbstractString; _...) = (print(io, TOML_DQUOTE); _toml_escape_str!(io, val); print(io, TOML_DQUOTE))
_toml_value(io::IO, val::Symbol; kw...) = _toml_value(io, string(val); kw...)
_toml_value(io::IO, val::AbstractChar; kw...) = _toml_value(io, string(val); kw...)
_toml_value(io::IO, val::Bool; _...) = print(io, val ? "true" : "false")
function _toml_value(io::IO, val::Integer; _...)
    if val isa Int128 || val isa UInt128 || val isa BigInt
        print(io, val)
    elseif val < 0
        write(io, UInt8('-'))
        _toml_write_uint!(io, unsigned(-val))
    else
        _toml_write_uint!(io, unsigned(val))
    end
end

function _toml_value(io::IO, val::AbstractFloat; _...)
    if isnan(val)
        write(io, "nan")
    elseif isinf(val)
        write(io, val < 0 ? "-inf" : "inf")
    else
        buf = _toml_float_buf()
        n = Base.Ryu.writeshortest(buf, 1, Float64(val))
        @GC.preserve buf unsafe_write(io, pointer(buf), n - 1)
    end
end

_toml_value(io::IO, val::Number; _...) =
    isnan(val) ? print(io, "nan") :
    isinf(val) ? print(io, val < 0 ? "-inf" : "inf") :
    print(io, val)
_toml_value(io::IO, val::Enum; kw...) = _toml_value(io, string(val); kw...)
_toml_value(io::IO, val::Type; kw...) = _toml_value(io, string(val); kw...)
_toml_value(io::IO, val::Dates.TimeType; kw...) = _toml_value(io, string(val); kw...)
_toml_value(io::IO, val::Dates.DateTime; _...) = print(io, Dates.format(val, Dates.dateformat"YYYY-mm-dd\THH:MM:SS.sss"))
_toml_value(io::IO, val::Dates.Time; _...) = print(io, Dates.format(val, Dates.dateformat"HH:MM:SS.sss"))
_toml_value(io::IO, val::Dates.Date; _...) = print(io, Dates.format(val, Dates.dateformat"YYYY-mm-dd"))
_toml_value(io::IO, val::UUID; kw...) = _toml_value(io, string(val); kw...)

function _toml_key_valid(val::AbstractString)
    return all(c -> isletter(c) || isdigit(c) || c == '-' || c == '_', val)
end

function _toml_key(io::IO, val::AbstractString; _...)
    if _toml_key_valid(val)
        print(io, val)
    else
        print(io, TOML_DQUOTE)
        _toml_escape_str!(io, val)
        print(io, TOML_DQUOTE)
    end
end

function _toml_key(io::IO, val::Integer; _...)
    if val < 0
        write(io, UInt8('-'))
        _toml_write_uint!(io, unsigned(-val))
    else
        _toml_write_uint!(io, unsigned(val))
    end
end
_toml_key(io::IO, val::Bool; _...) = print(io, val ? "true" : "false")
_toml_key(io::IO, val::AbstractChar; kw...) = _toml_key(io, string(val); kw...)
_toml_key(io::IO, val::Symbol; kw...) = _toml_key(io, string(val); kw...)

function _toml_key_str(val)::String
    io = IOBuffer()
    _toml_key(io, val)
    return String(take!(io))
end

@inline function _toml_indent!(io::IO, level::Int)
    for _ in 1:level
        print(io, "  ")
    end
end

function _toml_pair!(io::IO, key, val::T; parent_key::String = "", level::Int = 0, kw...) where {T}
    key_str = isempty(parent_key) ? _toml_key_str(key) : parent_key * "." * _toml_key_str(key)
    print(io, '\n')
    _toml_indent!(io, level + 1)
    print(io, '[', key_str, "]\n")
    _to_toml!(io, get(kw, :strategy, DefaultStrategy()), val; parent_key = key_str, level = level + 1, kw...)
end

function _toml_pair_simple!(io::IO, key, val; level::Int = 0, kw...)
    _toml_indent!(io, level)
    _toml_key(io, key)
    print(io, " = ")
    _toml_value(io, val)
    print(io, '\n')
end

for ST in (AbstractString, Symbol, AbstractChar, Number, Dates.TimeType, UUID)
    @eval function _toml_pair!(io::IO, key, val::$ST; level::Int = 0, kw...)
        _toml_pair_simple!(io, key, val; level, kw...)
    end
end

function _toml_pair!(io::IO, key, val::AbstractVector; level::Int = 0, kw...)
    if isempty(val)
        _toml_indent!(io, level)
        _toml_key(io, key)
        print(io, " = []\n")
    elseif all(issimple, val)
        _toml_indent!(io, level)
        _toml_key(io, key)
        print(io, " = [")
        for (i, v) in enumerate(val)
            i > 1 && print(io, ',')
            _toml_value(io, v)
        end
        print(io, "]\n")
    else
        parent_key = get(kw, :parent_key, "")
        key_str = isempty(parent_key) ? _toml_key_str(key) : parent_key * "." * _toml_key_str(key)
        for v in val
            print(io, '\n')
            _toml_indent!(io, level + 1)
            print(io, "[[", key_str, "]]\n")
            for (k, vv) in _toml_pairs(get(kw, :strategy, DefaultStrategy()), v; kw...)
                _toml_pair!(io, k, vv; parent_key = key_str, level = level + 1, kw...)
            end
        end
    end
end

function _toml_pairs(strategy, val::AbstractDict; kw...)
    return sort([(k, v) for (k, v) in val], by = x -> !issimple(x[2]))
end

function _toml_pairs(strategy, val::T; kw...) where {T}
    kv = Tuple[]
    N = fieldcount(T)
    Base.@nexprs 32 i -> begin
        if i <= N
            fn_i = fieldnames(T)[i]
            k_i = ser_name(strategy, T, Val(fn_i))
            v_i = ser_type(strategy, T, ser_value(strategy, T, Val(fn_i), getfield(val, fn_i)))
            if !(isnull(v_i) || ser_skip(strategy, T, Val(fn_i), v_i))
                push!(kv, (k_i, v_i))
            end
        end
    end
    if N > 32
        for field in fieldnames(T)[33:end]
            k = ser_name(strategy, T, Val(field))
            v = ser_type(strategy, T, ser_value(strategy, T, Val(field), getfield(val, field)))
            (isnull(v) || ser_skip(strategy, T, Val(field), v)) && continue
            push!(kv, (k, v))
        end
    end
    return sort(kv, by = x -> !issimple(x[2]))
end

function _to_toml!(io::IO, strategy, data::T; kw...) where {T}
    for (k, v) in _toml_pairs(strategy, data; kw...)
        _toml_pair!(io, k, v; strategy = strategy, kw...)
    end
end

function to_toml(strategy, data::T; kw...)::String where {T}
    io = IOBuffer()
    try
        _to_toml!(io, strategy, data; kw...)
        return String(take!(io))
    finally
        close(io)
    end
end

to_toml(data; kw...) = to_toml(DefaultStrategy(), data; kw...)

function to_toml(io::IO, data; kw...)
    _to_toml!(io, DefaultStrategy(), data; kw...)
    return nothing
end
function to_toml(io::IO, strategy, data; kw...)
    _to_toml!(io, strategy, data; kw...)
    return nothing
end

end # module
