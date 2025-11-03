# De/DeParquet

@testset verbose = true "DeParquet" begin
    @testset "Case №1: Deserialize Parquet to Struct" begin
        struct ParquetRecord
            id::Int64
            name::String
            value::Float64
        end

        # Create test data
        test_data = [
            ParquetRecord(1, "Alice", 100.5),
            ParquetRecord(2, "Bob", 200.3),
            ParquetRecord(3, "Charlie", 150.7),
        ]

        temp_file = tempname() * ".parquet"

        try
            # Write test data
            Serde.to_parquet(temp_file, test_data)

            # Deserialize it back
            result = Serde.deser_parquet(ParquetRecord, temp_file)

            @test length(result) == 3
            @test result[1] == ParquetRecord(1, "Alice", 100.5)
            @test result[2] == ParquetRecord(2, "Bob", 200.3)
            @test result[3] == ParquetRecord(3, "Charlie", 150.7)
        finally
            isfile(temp_file) && rm(temp_file)
        end
    end

    @testset "Case №2: Deserialize with Type Conversion" begin
        struct TypeConvRecord
            id::Int64
            score::Float64
        end

        # Create source data with different but compatible types
        struct SourceRecord
            id::Int64
            score::Int64  # Will be converted to Float64
        end

        source_data = [
            SourceRecord(1, 95),
            SourceRecord(2, 87),
        ]

        temp_file = tempname() * ".parquet"

        try
            Serde.to_parquet(temp_file, source_data)

            result = Serde.deser_parquet(TypeConvRecord, temp_file)

            @test length(result) == 2
            @test result[1].id == 1
            @test result[1].score isa Float64
            @test result[1].score == 95.0
        finally
            isfile(temp_file) && rm(temp_file)
        end
    end

    @testset "Case №3: Exception Handling" begin
        struct NonExistentRecord
            id::Int64
        end

        # Test with non-existent file
        @test_throws Serde.ParParquet.ParquetSyntaxError Serde.deser_parquet(
            NonExistentRecord,
            "nonexistent.parquet"
        )
    end
end
