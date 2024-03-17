# Utl/Macros

@testset verbose = true "Macros" begin
    @testset "Case №1: All decorators" begin
        @serde @default_value @de_name @ser_name mutable struct Foo_def_ser
            a::Int64 | 1 | "first"  | "a"
            b::Int64 | 2 | "b"      | "second"
        end

        Base.:(==)(l::Foo_def_ser, r::Foo_def_ser) = l.a == r.a && l.b == r.b

        exp_kvs = Dict{String,Any}()
        exp_obj = Foo_def_ser(1, 2)
        @test Serde.deser(Foo_def_ser, exp_kvs) == exp_obj

        exp_kvs = Dict{String,Any}("first" => 19)
        exp_obj = Foo_def_ser(19, 2)
        @test Serde.deser(Foo_def_ser, exp_kvs) == exp_obj

        exp_kvs = Dict{String,Any}("first" => 19)
        exp_obj = Foo_def_ser(19, 2)
        desered = Serde.deser(Foo_def_ser, exp_kvs)
        @test desered == exp_obj

        exp_str = "{\"a\":19,\"second\":2}"
        sered = Serde.to_json(desered)
        @test sered == exp_str
    end

    @testset "Case №2: @ser_name @de_name" begin
        @serde @ser_name @de_name struct Foo_ser_de
            a::Int64 | "ser-name" | "a"
            b::Int64 | "b"        | "de-name"
        end

        Base.:(==)(l::Foo_ser_de, r::Foo_ser_de) = l.a == r.a && l.b == r.b

        exp_kvs = Dict{String,Any}("a" => 11, "de-name" => 12)
        exp_obj = Foo_ser_de(11, 12)
        desered = Serde.deser(Foo_ser_de, exp_kvs)
        @test desered == exp_obj

        exp_str = "{\"ser-name\":11,\"b\":12}"
        sered = Serde.to_json(desered)
        @test sered == exp_str
    end

    @testset "Case №3: @de_name @default_value" begin
        @serde @de_name @default_value mutable struct Foo_de_def
            a::Int64 | "first" | 1
            b::Int64 | "b"     | 2
        end

        Base.:(==)(l::Foo_de_def, r::Foo_de_def) = l.a == r.a && l.b == r.b

        exp_kvs = Dict{String,Any}()
        exp_obj = Foo_de_def(1, 2)
        @test Serde.deser(Foo_de_def, exp_kvs) == exp_obj

        exp_kvs = Dict{String,Any}("first" => 3)
        exp_obj = Foo_de_def(3, 2)
        @test Serde.deser(Foo_de_def, exp_kvs) == exp_obj
    end

    @testset "Case №4: @ser_name @default_value" begin
        @serde @ser_name @default_value mutable struct Foo_ser_def
            a::Int64 | "a"      | 1
            b::Int64 | "second" | 2
        end

        Base.:(==)(l::Foo_ser_def, r::Foo_ser_def) = l.a == r.a && l.b == r.b

        exp_kvs = Dict{String,Any}()
        exp_obj = Foo_ser_def(1, 2)
        @test Serde.deser(Foo_ser_def, exp_kvs) == exp_obj

        exp_kvs = Dict{String,Any}("a" => 19)
        exp_obj = Foo_ser_def(19, 2)
        desered = Serde.deser(Foo_ser_def, exp_kvs)
        @test desered == exp_obj

        exp_str = "{\"a\":19,\"second\":2}"
        sered = Serde.to_json(desered)
        @test sered == exp_str
    end

    @testset "Case №5: @default_value" begin
        @serde @default_value mutable struct Foo_def
            a::Int64 | 1
            b::Int64 | 2
        end

        Base.:(==)(l::Foo_def, r::Foo_def) = l.a == r.a && l.b == r.b

        exp_kvs = Dict{String,Any}()
        exp_obj = Foo_def(1, 2)
        @test Serde.deser(Foo_def, exp_kvs) == exp_obj
    end

    @testset "Case №6: @de_name" begin
        @serde @de_name mutable struct Foo_de
            a::Int64 | "first"
            b::Int64 | "b"
        end

        Base.:(==)(l::Foo_de, r::Foo_de) = l.a == r.a && l.b == r.b

        exp_kvs = Dict{String,Any}("first" => 19, "b" => 20)
        exp_obj = Foo_de(19, 20)
        @test Serde.deser(Foo_de, exp_kvs) == exp_obj
    end

    @testset "Case №7: @ser_name" begin
        @serde @ser_name mutable struct Foo_ser
            a::Int64 | "a"
            b::Int64 | "second"
        end

        Base.:(==)(l::Foo_ser, r::Foo_ser) = l.a == r.a && l.b == r.b

        exp_kvs = Dict{String,Any}("a" => 19, "b" => 2)
        exp_obj = Foo_ser(19, 2)
        desered = Serde.deser(Foo_ser, exp_kvs)
        @test desered == exp_obj

        exp_str = "{\"a\":19,\"second\":2}"
        sered = Serde.to_json(desered)
        @test sered == exp_str
    end

    @testset "Case №8: @pascal_case" begin
        struct PascalCase
            id::Int64
            title::String
            is_active::Bool
        end

        Serde.@pascal_case(PascalCase)

        deserialized = Serde.deser_json(
            PascalCase,
            "{\"Id\":42,\"Title\":\"A New Beginning\",\"IsActive\":true}",
        )
        expected_obj = PascalCase(42, "A New Beginning", true)
        @test deserialized == expected_obj
    end

    @testset "Case №9: @camel_case" begin
        struct CamelCase
            user_id::Int64
            email_address::String
            subscription_date::Date
        end

        Serde.@camel_case(CamelCase)
        Serde.deser(::Type{CamelCase}, ::Type{Date}, v::String) = Date(v)

        deserialized = Serde.deser_json(
            CamelCase,
            "{\"userId\":85,\"emailAddress\":\"user@example.com\",\"subscriptionDate\":\"2023-09-15\"}",
        )
        expected_obj = CamelCase(85, "user@example.com", Date(2023, 9, 15))
        @test deserialized == expected_obj
    end

    @testset "Case №10: @kebab_case" begin
        struct KebabCase
            product_count::Int64
            last_purchase_price::Float64
            category_name::String
        end

        Serde.@kebab_case(KebabCase)

        deserialized = Serde.deser_json(
            KebabCase,
            "{\"product-count\":150,\"last-purchase-price\":79.99,\"category-name\":\"Electronics\"}",
        )
        expected_obj = KebabCase(150, 79.99, "Electronics")
        @test deserialized == expected_obj
    end
end
