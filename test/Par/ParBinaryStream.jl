using Test
using Dates
using NanoDates
using Serde

@testset "ParBinaryStream" begin
    bytes = Serde.to_binarystream(Vector{UInt16}([1, 2, 3, 4]))
    parsed_vector = Serde.parse_binarystream(Vector{UInt16}, bytes)
    @test parsed_vector == UInt16[1, 2, 3, 4]

    struct BinTime
        day::Date
        stamp::NanoDate
    end

    value = BinTime(Date(2024, 1, 1), NanoDate("2024-02-02T03:04:05.123456789"))
    struct_bytes = Serde.to_binarystream(value)
    parsed_struct = Serde.parse_binarystream(BinTime, struct_bytes)

    @test parsed_struct.day == value.day
    @test parsed_struct.stamp == value.stamp
end
