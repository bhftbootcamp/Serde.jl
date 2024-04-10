using Test
include("../../src/Ser/SerBson.jl")

@testset "SerBson" begin
    @testset "Date conversion" begin
        date_value = Date(2024, 4, 10)
        bson_doc = SerBson.to_bson(date_value)
        date_str = string(date_value)
        @test haskey(bson_doc, date_str)
        @test typeof(bson_doc[date_str]) == String
        @test bson_doc[date_str] == "2024-04-10"
    end

    @testset "UInt8 vector conversion" begin
        binary_value = UInt8[0x01, 0x02, 0x03]
        bson_doc = SerBson.to_bson(binary_value)
        @test haskey(bson_doc, "value")
        @test typeof(bson_doc["value"]) == BSON.Binary
        @test bson_doc["value"].data == binary_value
    end

    @testset "Dictionary serialization" begin
        dict_value = Dict("a" => 1, "b" => "test", "c" => Date(2024, 4, 10))
        bson_doc = SerBson.to_bson(dict_value)
        @test length(keys(bson_doc)) == 3
        @test bson_doc["a"] == 1
        @test bson_doc["b"] == "test"
        @test bson_doc["c"] == "2024-04-10"
    end

    @testset "Array serialization" begin
        array_value = [1, "test", Date(2024, 4, 10)]
        bson_doc = SerBson.to_bson(array_value)
        @test haskey(bson_doc, "array")
        @test typeof(bson_doc["array"]) == Vector{Any}
        @test length(bson_doc["array"]) == 3
        @test bson_doc["array"][1] == 1
        @test bson_doc["array"][2] == "test"
        @test bson_doc["array"][3] == "2024-04-10"
    end

    @testset "Custom Type serialization" begin
        struct CustomType
            a::Int
            b::String
            c::Date
        end
        custom_value = CustomType(1, "test", Date(2024, 4, 10))
        bson_doc = SerBson.to_bson(custom_value)
        @test length(keys(bson_doc)) == 3
        @test bson_doc["a"] == 1
        @test bson_doc["b"] == "test"
        @test bson_doc["c"] == "2024-04-10"
    end
end
