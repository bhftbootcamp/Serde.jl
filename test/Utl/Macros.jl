# Utl/Macros

@testset verbose = true "Macros" begin
    @testset "Case №1: All decorators" begin
        @serde @default_value @de_name @ser_json_name mutable struct Foo_def_ser
            a::Int64 | 1 | "first"  | "a"
            b::Int64 | 2 | "b"      | "second"
        end

        @test Serde.deser(Foo_def_ser, Dict{String,Any}()).b == 2
        @test Serde.deser(Foo_def_ser, Dict{String,Any}("first" => 19)).a == 19
        @test Serde.to_json(Serde.deser(Foo_def_ser, Dict{String,Any}("first" => 19))) == "{\"a\":19,\"second\":2}"
    end

    @testset "Case №2: @ser_json_name @de_name" begin
        @serde @ser_json_name @de_name struct Foo_ser_de
            a::Int64 | "ser-name" | "a"
            b::Int64 | "b"        | "de-name"
        end

        @test Serde.deser(Foo_ser_de, Dict{String,Any}("a" => 11, "de-name" => 12)).b == 12
        @test Serde.to_json(Serde.deser(Foo_ser_de, Dict{String,Any}("a" => 11, "de-name" => 12))) == "{\"ser-name\":11,\"b\":12}"
    end

    @testset "Case №3: @de_name @default_value" begin
        @serde @de_name @default_value mutable struct Foo_de_def
            a::Int64 | "first" | 1
            b::Int64 | "b"     | 2
        end

        @test Serde.deser(Foo_de_def, Dict{String,Any}()).a == 1
        @test Serde.deser(Foo_de_def, Dict{String,Any}("first" => 3)).a == 3
    end

    @testset "Case №4: @ser_json_name @default_value" begin
        @serde @ser_json_name @default_value mutable struct Foo_ser_def
            a::Int64 | "a"      | 1
            b::Int64 | "second" | 2
        end

        @test Serde.to_json(Serde.deser(Foo_ser_def, Dict{String,Any}("a" => 19))) == "{\"a\":19,\"second\":2}"
        @test Serde.deser(Foo_ser_def, Dict{String,Any}()).b == 2
    end

    @testset "Case №5: @default_value" begin
        @serde @default_value mutable struct Foo_def
            a::Int64 | 1
            b::Int64 | 2
        end

        @test Serde.deser(Foo_def, Dict{String,Any}()).b == 2
    end

    @testset "Case №6: @de_name" begin
        @serde @de_name mutable struct Foo_de
            a::Int64 | "first"
            b::Int64 | "b"
        end

        @test Serde.deser(Foo_de, Dict{String,Any}("first" => 19, "b" => 20)).a == 19
    end

    @testset "Case №7: @ser_json_name" begin
        @serde @ser_json_name mutable struct Foo_ser
            a::Int64 | "a"
            b::Int64 | "second"
        end

        @test Serde.to_json(Serde.deser(Foo_ser, Dict{String,Any}("a" => 19, "b" => 2))) == "{\"a\":19,\"second\":2}"
    end
end
