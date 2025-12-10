module Custom

export NumericStringToNumberJsonParser,
       CamelToSnakeJsonParser

using ..Strategy
using ..Serde

const INT_RE = r"^\s*[+-]?\d+\s*$"

_normalize_identity(x) = x

function _normalize_numbers_inplace!(x)
    return x
end

function _normalize_numbers_inplace!(s::AbstractString)
    return occursin(INT_RE, s) ? Base.parse(Int, s) : s
end

function _normalize_numbers_inplace!(v::AbstractVector)
    for i in eachindex(v)
        v[i] = _normalize_numbers_inplace!(v[i])
    end
    return v
end

function _normalize_numbers_inplace!(d::AbstractDict)
    for (k, v) in d
        d[k] = _normalize_numbers_inplace!(v)
    end
    return d
end

function camel_to_snake(s::AbstractString)::String
    buf = IOBuffer()
    for (i, c) in enumerate(s)
        if isuppercase(c) && i != 1
            print(buf, '_', lowercase(c))
        else
            print(buf, lowercase(c))
        end
    end
    return String(take!(buf))
end

function _camel_to_snake_keys!(x)
    return x
end

function _camel_to_snake_keys!(v::AbstractVector)
    for i in eachindex(v)
        v[i] = _camel_to_snake_keys!(v[i])
    end
    return v
end

function _camel_to_snake_keys!(d::AbstractDict)
    keys_list = collect(keys(d))
    for k in keys_list
        v = d[k]
        newk = k
        if k isa AbstractString
            newk = camel_to_snake(k)
        elseif k isa Symbol
            newk = Symbol(camel_to_snake(String(k)))
        end
        if newk != k
            delete!(d, k)
            d[newk] = _camel_to_snake_keys!(v)
        else
            d[k] = _camel_to_snake_keys!(v)
        end
    end
    return d
end

"""
    NumericStringToNumberJsonParser <: AbstractParserStrategy

JSON parser strategy that converts numeric-looking strings to integers
after parsing with the default JSON parser.
"""
struct NumericStringToNumberJsonParser <: AbstractParserStrategy end

function Strategy.parse(::NumericStringToNumberJsonParser, x::AbstractString; kw...)
    obj = Serde.parse_json(x; kw...)
    return _normalize_numbers_inplace!(obj)
end

"""
    CamelToSnakeJsonParser <: AbstractParserStrategy

JSON parser strategy that converts all object keys from camelCase to snake_case.
"""
struct CamelToSnakeJsonParser <: AbstractParserStrategy end

function Strategy.parse(::CamelToSnakeJsonParser, x::AbstractString; kw...)
    obj = Serde.parse_json(x; kw...)
    return _camel_to_snake_keys!(obj)
end

end
