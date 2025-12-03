# Ser/SerMessagePack

using Test
using Dates
using Serde

@testset "SerMessagePack" begin
    struct MPPosition
        symbol::String
        qty::Int64
    end

    struct MPTrade
        name::String
        balance::Float64
        is_trader::Bool
        created_at::DateTime
        payload::Vector{UInt8}
        positions::Vector{MPPosition}
    end

    trade = MPTrade(
        "Alice",
        100.5,
        true,
        DateTime(2024, 1, 1, 12, 30),
        b"payload",
        [MPPosition("AAPL", 10), MPPosition("MSFT", 5)],
    )

    bytes = Serde.to_messagepack(trade)
    parsed = Serde.parse_messagepack(bytes)

    @test parsed["name"] == "Alice"
    @test parsed["payload"] == b"payload"
    @test parsed["positions"][1]["symbol"] == "AAPL"
    @test parsed["created_at"] == DateTime(2024, 1, 1, 12, 30)

    rebuilt = Serde.deser_messagepack(MPTrade, bytes)
    @test rebuilt.name == trade.name
    @test rebuilt.balance == trade.balance
    @test rebuilt.is_trader == trade.is_trader
    @test rebuilt.created_at == trade.created_at
    @test rebuilt.payload == trade.payload
    @test length(rebuilt.positions) == 2
    @test rebuilt.positions[1].symbol == "AAPL"
    @test rebuilt.positions[1].qty == 10
    @test rebuilt.positions[2].symbol == "MSFT"
    @test rebuilt.positions[2].qty == 5
end
