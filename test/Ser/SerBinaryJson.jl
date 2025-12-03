# Ser/SerBinaryJson

using Test
using Dates
using Serde

@testset "SerBinaryJson" begin
    struct Position
        symbol::String
        qty::Int64
    end

    struct Trade
        name::String
        balance::Float64
        is_trader::Bool
        created_at::DateTime
        payload::Vector{UInt8}
        positions::Vector{Position}
    end

    trade = Trade(
        "Alice",
        100.5,
        true,
        DateTime(2024, 1, 1, 12, 30),
        b"payload",
        [Position("AAPL", 10), Position("MSFT", 5)],
    )

    bytes = Serde.to_binaryjson(trade)
    parsed = Serde.parse_binaryjson(bytes)

    @test parsed["name"] == "Alice"
    @test parsed["payload"] == b"payload"
    @test parsed["positions"][1]["symbol"] == "AAPL"
    @test parsed["created_at"] == DateTime(2024, 1, 1, 12, 30)

    rebuilt = Serde.deser_binaryjson(Trade, bytes)
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
