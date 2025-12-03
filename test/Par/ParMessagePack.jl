# Par/ParMessagePack

using Test
using Dates
using Serde

@testset "ParMessagePack" begin
    sample = Dict(
        "name" => "Alice",
        "numbers" => [1, 2, 3],
        "when" => DateTime(2024, 1, 1, 12),
        "payload" => b"hello",
    )
    bytes = Serde.to_messagepack(sample)
    parsed = Serde.parse_messagepack(bytes)
    @test parsed["name"] == "Alice"
    @test parsed["numbers"] == [1, 2, 3]
    @test parsed["when"] == DateTime(2024, 1, 1, 12)
    @test parsed["payload"] == b"hello"
end
