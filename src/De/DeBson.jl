module DeBson

# Ensure BSON package is available
using BSON

export deser_bson

"""
    deser_bson(::Type{T}, bson_path::String; kw...) -> T

Deserialize a BSON file specified by `bson_path` into an instance of type `T`.

# Arguments
- `T`: The type to deserialize into.
- `bson_path`: Path to the BSON file.

# Keyword Arguments
- `kw`: Additional keyword arguments for customization.

# Examples
```julia
struct Record
    count::Float64
end

struct Data
    id::Int64
    name::String
    body::Record
end

# Assuming `data.bson` represents a `Data` instance
deserialized_data = deser_bson(Data, "data.bson")
"""
function deser_bson(::Type{T}, bson_path::String; kw...) where T
    bson_data = BSON.load(bson_path; kw...)
    # Manually construct the object of type T from bson_data
    if T != Nothing && T != Missing
        fields = [bson_data[Symbol(fieldname)] for fieldname in fieldnames(T)]
        return T(fields...)
    elseif T == Nothing
        return nothing
    elseif T == Missing
        return missing
    end
end

# Special case handlers
deser_bson(::Type{Nothing}, _) = nothing
deser_bson(::Type{Missing}, _) = missing

end    