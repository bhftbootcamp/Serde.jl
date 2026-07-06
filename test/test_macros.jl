@testset "Case conversion" begin
    @test Serde.to_camel_case("hello_world") == "helloWorld"
    @test Serde.to_pascal_case("hello_world") == "HelloWorld"
    @test Serde.to_kebab_case("hello_world") == "hello-world"
    @test Serde.to_snake_case("helloWorld") == "hello_world"
    @test Serde.to_snake_case("HelloWorld") == "hello_world"
end

@testset "Built-in case contexts" begin
    struct _CaseStruct
        my_field::Int
        other_value::String
    end

    @testset "CamelCase" begin
        obj = Serde.deser(CamelCase(), _CaseStruct, Dict("myField" => 1, "otherValue" => "x"))
        @test obj.my_field == 1
        @test obj.other_value == "x"

        json = to_json(CamelCase(), _CaseStruct(2, "y"))
        @test contains(json, "myField")
        @test contains(json, "otherValue")
        @test !contains(json, "my_field")
    end

    @testset "PascalCase" begin
        obj = Serde.deser(PascalCase(), _CaseStruct, Dict("MyField" => 3, "OtherValue" => "z"))
        @test obj.my_field == 3
        @test obj.other_value == "z"

        json = to_json(PascalCase(), _CaseStruct(4, "w"))
        @test contains(json, "MyField")
        @test contains(json, "OtherValue")
    end

    @testset "KebabCase" begin
        obj = Serde.deser(KebabCase(), _CaseStruct, Dict("my-field" => 5, "other-value" => "v"))
        @test obj.my_field == 5
        @test obj.other_value == "v"

        json = to_json(KebabCase(), _CaseStruct(6, "u"))
        @test contains(json, "my-field")
        @test contains(json, "other-value")
    end

    @testset "LowerCase" begin
        obj = Serde.deser(LowerCase(), _CaseStruct, Dict("my_field" => 7, "other_value" => "t"))
        @test obj.my_field == 7
        @test obj.other_value == "t"

        json = to_json(LowerCase(), _CaseStruct(8, "s"))
        @test contains(json, "my_field")
        @test contains(json, "other_value")
    end
end
