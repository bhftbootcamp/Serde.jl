# runtests.jl

using Serde
using Test, Dates, UUIDs

@testset "Serde.jl v4" begin
    include("test_types.jl")
    include("test_traits.jl")
    include("test_ser.jl")
    include("test_deser.jl")
    include("test_macros.jl")
    include("test_tagged_unions.jl")
    include("test_json.jl")
    include("test_toml.jl")
    include("test_csv.jl")
    include("test_query.jl")
    include("test_msgpack.jl")
    include("test_bson.jl")
    include("test_xml.jl")
    include("test_yaml.jl")
    include("test_context.jl")
    include("test_with.jl")
    include("test_edge_cases.jl")
end
