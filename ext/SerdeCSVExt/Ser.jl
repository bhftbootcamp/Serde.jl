module SerCsv

export to_csv

import Serde.to_flatten

const WRAPPED = Set{Char}(['"', ',', ';', '\n'])

function wrap_value(s::AbstractString)
    for i in eachindex(s)
        if s[i] in WRAPPED
            escaped_s = replace(s, "\"" => "\"\"")
            return "\"$escaped_s\""
        end
    end
    return s
end

function to_csv(
    data::Vector{T};
    delimiter::String = ",",
    headers::Vector{String} = String[],
    with_names::Bool = true,
)::String where {T}
    cols = Set{String}()
    vals = Vector{Dict{String,Any}}(undef, length(data) + with_names)

    for (index, item) in enumerate(data)
        val = to_flatten(item)
        push!(cols, keys(val)...)
        vals[index + with_names] = val
    end

    with_names && (vals[1] = Dict{String,String}(cols .=> string.(cols)))
    t_cols = isempty(headers) ? sort([cols...]) : headers
    l_cols = t_cols[end]
    buf = IOBuffer()

    for csv_item in vals
        for col in t_cols
            val = get(csv_item, col, nothing)
            str = val === nothing ? "" : wrap_value(string(val))
            print(buf, str, col != l_cols ? delimiter : "\n")
        end
    end

    return String(take!(buf))
end

end
