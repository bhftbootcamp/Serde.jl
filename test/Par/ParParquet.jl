# Par/ParParquet

@testset verbose = true "ParParquet" begin
    @testset "Case №1: Normal Parquet Parsing" begin
        # Create test data
        struct TestRecord
            id::Int64
            name::String
            value::Float64
        end

        test_data = [
            TestRecord(1, "Alice", 100.5),
            TestRecord(2, "Bob", 200.3),
            TestRecord(3, "Charlie", 150.7),
        ]

        # Create a temporary parquet file
        temp_file = tempname() * ".parquet"

        try
            # Write test data
            Serde.to_parquet(temp_file, test_data)

            # Parse it back
            parsed = Serde.parse_parquet(temp_file)

            @test length(parsed) == 3
            @test parsed[1].id == 1
            @test parsed[1].name == "Alice"
            @test parsed[1].value == 100.5
            @test parsed[2].id == 2
            @test parsed[2].name == "Bob"
            @test parsed[3].id == 3
            @test parsed[3].name == "Charlie"
        finally
            # Cleanup
            isfile(temp_file) && rm(temp_file)
        end
    end

    @testset "Case №2: Exception Handling in Parquet Parsing" begin
        # Test with non-existent file
        @test_throws Serde.ParParquet.ParquetSyntaxError Serde.parse_parquet("nonexistent_file.parquet")
    end
end
