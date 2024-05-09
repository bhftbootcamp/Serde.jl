# Ser/SerCsv

@testset verbose = true "Serialization to CSV Test Suite" begin
    @testset "Case 1: Simple Serialization" begin
        struct SimpleRecord
            a_id::Int64
            b_category::String
            c_quantity::Int64
            d_value::String
        end

        exp_obj = [
            SimpleRecord(1, "a", 11, "11.1"),
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
            data::SubRecord
        end

        exp_obj = [
            ComplexRecord(1, "Hello", 3, SubRecord(42, NestedDetail("Nested object1"))),
            ComplexRecord(2, "Julia", 5, SubRecord(43, NestedDetail("Nested object2"))),
            ComplexRecord(3, "Coconut", 7, SubRecord(44, NestedDetail("Nested object3"))),
        ]
        exp_str = """
        id,name,count,data_code,data_nested_detail
        1,Hello,3,42,Nested object1
        2,Julia,5,43,Nested object2
        3,Coconut,7,44,Nested object3
        """
        @test Serde.to_csv(
            exp_obj,
            headers = ["id", "name", "count", "data_code", "data_nested_detail"],
        ) |> strip == exp_str |> strip
    end

    @testset "Case 3: Wrapping Values with Special Characters" begin
        struct SpecialCharRecord
            id::Int64
            text::String
            count::Int64
            value::String
        end

        exp_obj = [
            SpecialCharRecord(1, "a,,,,;", 11, "11.1"),
            SpecialCharRecord(2, "b\nl", 22, "bb\"\""),
            SpecialCharRecord(1, "a,,,,;", 12, "11.1"),
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

    @testset "Case 5: Serializing Order" begin
        struct Bar500
            num::Float64
            str::String
        end

        struct Foo500
            val::Int64
            bar::Bar500
            str::String
        end
        nested_struct = [Foo500(1, Bar500(1.0,"b"), "a")]
        exp_str = """
        val,bar_num,bar_str,str
        1,1.0,b,a
        """
        @test Serde.to_csv(nested_struct) == exp_str

        struct FooBar500
            bar::Bar500
            foo::Foo500
        end
        nested_struct2 = [FooBar500(Bar500(2.0,"a"),Foo500(1, Bar500(1.0,"b"), "a"))
        FooBar500(Bar500(3.0,"a"),Foo500(1, Bar500(1.0,"b"), "a"))
        ]
        exp_str2 = """
        bar_num,bar_str,foo_val,foo_bar_num,foo_bar_str,foo_str
        2.0,a,1,1.0,b,a
        3.0,a,1,1.0,b,a
        """
        @test Serde.to_csv(nested_struct2) == exp_str2
    end

    @testset "Case №6: Get header and value for Simple Type and Nested Type" begin
        struct SimpleRecord2
            a_id::Int64
            b_category::String
            c_quantity::Int64
            d_value::String
        end
        obj = SimpleRecord2(1, "a", 11, "11.1")
        exp_obj = Serde.SerCsv.get_headers(SimpleRecord2)
        # exp_row_val = Serde.SerCsv.get_row_values(obj)
        @test exp_obj == ["a_id","b_category","c_quantity","d_value"]
        # @test exp_row_val == [1, "a", 11, "11.1"]
        @test Serde.SerCsv.to_csv([obj];delimiter="|") == """
        a_id|b_category|c_quantity|d_value
        1|a|11|11.1
        """

        struct SimpleRecord3
            a_id::Int64
            b_category::String
            c_quantity::Int64
            d_value::SimpleRecord2
            e_value::Int64
        end
        obj = SimpleRecord3(1,"2",11,SimpleRecord2(1, "a", 11, "11.1"),1)
        exp_obj = Serde.SerCsv.get_headers(SimpleRecord3)
        # exp_row_val = Serde.SerCsv.get_row_values(obj)
        @test exp_obj == ["a_id","b_category","c_quantity","d_value_a_id","d_value_b_category","d_value_c_quantity","d_value_d_value","e_value"]
        # @test exp_row_val == [1,"2",11,1, "a", 11, "11.1",1]
        @test Serde.SerCsv.to_csv([obj]) == """
        a_id,b_category,c_quantity,d_value_a_id,d_value_b_category,d_value_c_quantity,d_value_d_value,e_value
        1,2,11,1,a,11,11.1,1
        """

        struct SimpleRecord4
            a_id::Int64
            b_category::String
            c_quantity::Int64
            d_value::Union{String,Nothing}
        end
        obj = SimpleRecord4(1, "a", 11, nothing)
        exp_obj = Serde.SerCsv.get_headers(SimpleRecord4)
        # exp_row_val = Serde.SerCsv.get_row_values(obj)
        @test exp_obj == ["a_id","b_category","c_quantity","d_value"]
        # @test exp_row_val == [1, "a", 11, nothing]
        @test Serde.SerCsv.to_csv([obj]) == """
        a_id,b_category,c_quantity,d_value
        1,a,11,
        """

        struct SimpleRecord5
            a_id::Int64
            b_category::String
            c_quantity::Int64
            d_value::Union{SimpleRecord2,Nothing}
            e_value::Int64
        end
        obj = SimpleRecord5(1,"2",11,nothing,1)
        exp_obj = Serde.SerCsv.get_headers(SimpleRecord5)
        # exp_row_val = Serde.SerCsv.get_row_values(obj)
        @test exp_obj == ["a_id","b_category","c_quantity","d_value_a_id","d_value_b_category","d_value_c_quantity","d_value_d_value","e_value"]
        # @test exp_row_val == [1,"2",11,nothing,nothing,nothing,nothing,1]
        @test Serde.SerCsv.to_csv([obj]) == """
        a_id,b_category,c_quantity,d_value_a_id,d_value_b_category,d_value_c_quantity,d_value_d_value,e_value
        1,2,11,,,,,1
        """
    end
end
