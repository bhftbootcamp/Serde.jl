using Test
using Dates
using NanoDates
using Serde

@testset "SerBinaryStream" begin
    struct StreamUser
        id::UInt16
        active::Bool
        name::String
        joined_at::DateTime
        tags::Vector{String}
        nickname::Union{Nothing,String}
    end

    user = StreamUser(
        42,
        true,
        "Bob",
        DateTime(2024, 5, 1, 12, 0, 0),
        ["alpha", "beta"],
        nothing,
    )

    bytes = Serde.to_binarystream(user)
    rebuilt = Serde.deser_binarystream(StreamUser, bytes)

    @test rebuilt.id == user.id
    @test rebuilt.active == user.active
    @test rebuilt.name == user.name
    @test rebuilt.joined_at == user.joined_at
    @test rebuilt.tags == user.tags
    @test rebuilt.nickname === nothing

    serializer = Serde.Strategy.BinaryStreamSerializer()
    parser = Serde.Strategy.BinaryStreamParser()
    raw = Serde.serialize(serializer, Union{Nothing,String}, nothing)
    @test Serde.Strategy.parse(parser, Union{Nothing,String}, raw) === nothing
end
