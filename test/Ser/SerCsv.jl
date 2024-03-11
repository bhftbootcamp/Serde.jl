# Ser/SerCsv
import CSV

@testset verbose = true "Serialization to CSV Test Suite" begin
    @testset "Case 1: Simple Serialization" begin
        struct SimpleRecord
            a_id::Int64
            b_category::String
            c_quantity::Int64
            d_value::Union{String,Float64}
        end

        exp_obj = [
            SimpleRecord(1, "a", 11, 11.1),
            SimpleRecord(2, "b", 22, "bb"),
            SimpleRecord(2, "b", 22, "bb"),
        ]
        exp_str = """
        a_id,b_category,c_quantity,d_value
        1,a,11,11.1
        2,b,22,bb
        2,b,22,bb
        """
        @test Serde.to_csv(exp_obj) |> strip == exp_str |> strip
    end

    @testset "Case 2: Normalization with Nested Structures" begin
        struct NestedDetail
            detail::String
        end

        struct SubRecord
            code::Int64
            nested::NestedDetail
        end

        struct ComplexRecord
            id::Int64
            name::String
            count::Int64
            data::Union{String,Float64,SubRecord}
        end

        exp_obj = [
            ComplexRecord(1, "Hello", 3, "World"),
            ComplexRecord(2, "Julia", 5, 3.14),
            ComplexRecord(3, "Coconut", 7, SubRecord(42, NestedDetail("Nested object"))),
        ]
        exp_str = """
        id,name,count,data,data_code,data_nested_detail
        1,Hello,3,World,,
        2,Julia,5,3.14,,
        3,Coconut,7,,42,Nested object
        """
        @test Serde.to_csv(
            exp_obj,
            headers = ["id", "name", "count", "data", "data_code", "data_nested_detail"],
        ) |> strip == exp_str |> strip
    end

    @testset "Case 3: Wrapping Values with Special Characters" begin
        struct SpecialCharRecord
            id::Int64
            text::String
            count::Int64
            value::Union{String,Float64}
        end

        exp_obj = [
            SpecialCharRecord(1, "a,,,,;", 11, 11.1),
            SpecialCharRecord(2, "b\nl", 22, "bb\"\""),
            SpecialCharRecord(1, "a,,,,;", 12, 11.1),
        ]
        exp_str = """
        id,text,count,value
        1,"a,,,,;",11,11.1
        2,"b
        l",22,"bb\"\"\"\""
        1,"a,,,,;",12,11.1
        """
        @test Serde.to_csv(exp_obj, headers = ["id", "text", "count", "value"]) |> strip ==
              exp_str |> strip
    end

    @testset "Case 4: Serializing Dictionaries" begin
        exp_obj = [
            IdDict("a" => 10, "B" => 20),
            Dict("a" => 15, "B" => 32),
            WeakKeyDict("a" => 10, "B" => 35),
        ]
        expected_csv_with_delimiter = """
        B;a
        20;10
        32;15
        35;10
        """
        @test Serde.to_csv(exp_obj; delimiter = ";") |> strip ==
              expected_csv_with_delimiter |> strip

        exp_obj = [
            Dict("a" => 10, "B" => 20, "C" => Dict("cfoo" => "foo", "cbaz" => "baz")),
            Dict(:a => 10, :B => 20),
        ]
        exp_str = """
        a,B,C_cbaz,C_cfoo
        10,20,baz,foo
        10,20,,
        """
        @test Serde.to_csv(exp_obj, headers = ["a", "B", "C_cbaz", "C_cfoo"], with_names = true) |> strip ==
              exp_str |> strip

        exp_str = """
        10,20,baz,foo
        10,20,,
        """
        @test Serde.to_csv(exp_obj, headers = ["a", "B", "C_cbaz", "C_cfoo"], with_names = false) |> strip ==
              exp_str |> strip
    end
end
