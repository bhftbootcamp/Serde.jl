# Parquet format tests. The extension is loaded automatically once Parquet2
# and Tables are present in the test environment.
using Parquet2, Tables

@testset "Parquet — round-trip Vector{T}" begin
    struct _ParRow
        id::Int64
        name::String
        score::Float64
    end
    rows = [_ParRow(1, "a", 1.5), _ParRow(2, "b", 2.5), _ParRow(3, "c", 3.5)]
    bytes = to_parquet(rows)
    @test bytes isa Vector{UInt8}
    @test length(bytes) > 0

    back = from_parquet(Vector{_ParRow}, bytes)
    @test back == rows
end

@testset "Parquet — untyped parse returns rows of dicts" begin
    struct _ParRow2
        x::Int64
        y::String
    end
    rows = [_ParRow2(10, "ten"), _ParRow2(20, "twenty")]
    bytes = to_parquet(rows)
    parsed = parse_parquet(bytes)
    @test length(parsed) == 2
    @test parsed[1]["x"] == 10
    @test parsed[1]["y"] == "ten"
    @test parsed[2]["x"] == 20
end

@testset "Parquet — strategy threads through write and read" begin
    struct _ParRow3
        user_id::Int64
        full_name::String
    end
    rows = [_ParRow3(1, "Ada"), _ParRow3(2, "Linus")]
    bytes = to_parquet(CamelCase(), rows)
    # Round-trip via the same strategy.
    back = from_parquet(CamelCase(), Vector{_ParRow3}, bytes)
    @test back == rows

    # Untyped parse exposes the renamed columns.
    parsed = parse_parquet(bytes)
    @test haskey(parsed[1], "userId")
    @test haskey(parsed[1], "fullName")
    @test !haskey(parsed[1], "user_id")
end

@testset "Parquet — IO sink" begin
    struct _ParIO
        n::Int64
    end
    rows = [_ParIO(7), _ParIO(8)]
    io = IOBuffer()
    to_parquet(io, rows)
    bytes = take!(io)
    back = from_parquet(Vector{_ParIO}, bytes)
    @test back == rows
end

@testset "Parquet — try_from_parquet wraps errors" begin
    struct _ParTry
        n::Int64
    end
    @test try_from_parquet(Vector{_ParTry}, UInt8[]) isa SerdeError
    @test try_from_parquet(CamelCase(), Vector{_ParTry}, UInt8[]) isa SerdeError
end

@testset "Parquet — non-vector target rejected" begin
    struct _ParBad
        n::Int64
    end
    rows = [_ParBad(1)]
    bytes = to_parquet(rows)
    @test_throws ArgumentError from_parquet(_ParBad, bytes)
end

@testset "Parquet — empty Vector rejected on write" begin
    struct _ParE
        n::Int64
    end
    @test_throws ArgumentError to_parquet(_ParE[])
end
