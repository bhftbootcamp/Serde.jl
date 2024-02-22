# Utl/Macros

@testset verbose = true "Macros" begin
    @testset "Case №1: All decorators" begin
        @serde @default_value @de_name @ser_json_name mutable struct Foo_def_ser
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

    @testset "Case №2: @ser_json_name @de_name" begin
        @serde @ser_json_name @de_name struct Foo_ser_de
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

    @testset "Case №4: @ser_json_name @default_value" begin
        @serde @ser_json_name @default_value mutable struct Foo_ser_def
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

    @testset "Case №7: @ser_json_name" begin
        @serde @ser_json_name mutable struct Foo_ser
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
end
