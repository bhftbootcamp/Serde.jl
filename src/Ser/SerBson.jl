module SerBson

export to_bson

using BSON
using Dates
using ..Serde

function convert_to_bson_type(value)
    if value isa Date
        return string(value)
    elseif value isa Vector{UInt8}
        return BSON.binary(value)
    else
        return value
    end
end

function serialize!(bson_doc::Dict, data)
    if data isa AbstractDict
        for (key, value) in data
            bson_doc[key] = convert_to_bson_type(value)
        end
    elseif data isa AbstractArray
        bson_doc["array"] = [convert_to_bson_type(val) for val in data]
    else
        for field in fieldnames(typeof(data))
            value = getfield(data, field)
            bson_doc[string(field)] = convert_to_bson_type(value)
        end
    end
end


function to_bson(data)
    bson_doc = Dict{String, Any}()
    serialize!(bson_doc, data)
    return bson_doc
end

end