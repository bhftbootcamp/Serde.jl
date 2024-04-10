using Test
using BSON

# Include the module to be tested
include("../../src/De/DeBson.jl")  

# Test the `deser_bson` function
@testset "DeBson Tests" begin
    # Define test data
    struct TestData
        id::Int
        name::String
    end

    # Simulate BSON data
    bson_data = BSON.bson("test.bson", Dict(:id => 1, :name => "Test Name"))

    # Test deserialization
    @testset "Basic BSON Deserialization" begin
        # Deserialize BSON data
        deserialized_data = DeBson.deser_bson(TestData, "test.bson")
        
        # Expected result
        expected_result = TestData(1, "Test Name")
        
        # Assert equality
        @test deserialized_data == expected_result
    end

    # Test special cases
    @testset "Special Cases" begin
        # Test deserialization of Nothing
        @test DeBson.deser_bson(Nothing, bson_data) === nothing

        # Test deserialization of Missing
        @test DeBson.deser_bson(Missing, bson_data) === missing
    end
end
