# Ser/SerParquet

@testset verbose = true "SerParquet" begin
    @testset "Case №1: Serialize Struct to Parquet" begin
        struct ParquetTestData
            id::Int64
            name::String
            score::Float64
        end

        data = [
            ParquetTestData(1, "Alice", 95.5),
            ParquetTestData(2, "Bob", 87.3),
            ParquetTestData(3, "Charlie", 92.1),
        ]

        temp_file = tempname() * ".parquet"

        try
            # Write to parquet
            Serde.to_parquet(temp_file, data)

            # Verify file exists
            @test isfile(temp_file)

            # Read back and verify
            parsed = Serde.parse_parquet(temp_file)
            @test length(parsed) == 3
            @test parsed[1].id == 1
            @test parsed[1].name == "Alice"
            @test parsed[1].score == 95.5
        finally
            isfile(temp_file) && rm(temp_file)
        end
    end

    @testset "Case №2: Serialize Dict to Parquet" begin
        data = [
            Dict("id" => 1, "city" => "New York", "population" => 8.3),
            Dict("id" => 2, "city" => "Los Angeles", "population" => 3.9),
            Dict("id" => 3, "city" => "Chicago", "population" => 2.7),
        ]

        temp_file = tempname() * ".parquet"

        try
            # Write to parquet
            Serde.to_parquet(temp_file, data)

            # Verify file exists
            @test isfile(temp_file)

            # Read back and verify
            parsed = Serde.parse_parquet(temp_file)
            @test length(parsed) == 3
            # Note: order might be different because Dict keys are unordered
            @test haskey(first(parsed), :id)
            @test haskey(first(parsed), :city)
            @test haskey(first(parsed), :population)
        finally
            isfile(temp_file) && rm(temp_file)
        end
    end

    @testset "Case №3: Serialize Large Dataset" begin
        struct LargeTestData
            value::Int64
        end

        data = [LargeTestData(i) for i in 1:100]
        temp_file = tempname() * ".parquet"

        try
            # Write large dataset
            Serde.to_parquet(temp_file, data)

            @test isfile(temp_file)

            # Read back and verify
            parsed = Serde.parse_parquet(temp_file)
            @test length(parsed) == 100
            @test parsed[1].value == 1
            @test parsed[100].value == 100
        finally
            isfile(temp_file) && rm(temp_file)
        end
    end
end
