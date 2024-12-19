# deser

using Serde
using Test, Dates

@testset verbose = true "De" begin
    @testset "Case №1: Simple deserialization" begin
        struct Foo
            a::Int64
            b::Int64
        end

        exp_kvs = Dict{Symbol,Int64}(:a => 100, :b => 300)
        exp_obj = Foo(100, 300)
        @test Serde.deser(Foo, exp_kvs) == exp_obj

        exp_kvs = Dict{String,Int64}("a" => 100, "b" => 300)
        exp_obj = Foo(100, 300)
        @test Serde.deser(Foo, exp_kvs) == exp_obj

        exp_kvs = Dict{String,Int64}("a" => 100)
        @test_throws "ParamError: parameter 'b::Int64' was not passed or has the value 'nothing'" Serde.deser(
            Foo,
            exp_kvs,
        )

        exp_kvs = Dict{String,Real}("a" => 100.00001, "b" => 300)
        @test_throws "WrongType: for 'Foo' value '100.00001' has wrong type 'a::Float64', must be 'a::Int64'" Serde.deser(
            Foo,
            exp_kvs,
        )
    end

    @testset "Case №2: Deserialization with type casting" begin
        struct Foo2
            a::Int64
            b::Float64
        end

        exp_kvs = Dict{Symbol,Any}(:a => 100, :b => 300.0001)
        exp_obj = Foo2(100, 300.0001)
        @test Serde.deser(Foo2, exp_kvs) == exp_obj

        exp_kvs = Dict{String,Any}("a" => 100, "b" => "300")
        exp_obj = Foo2(100, 300)
        @test Serde.deser(Foo2, exp_kvs) == exp_obj
    end

    @testset "Case №3: Custom name" begin
        struct Foo3
            a::Float64
            other_name::String
        end

        Serde.custom_name(::Type{Foo3}, ::Val{:other_name}) = :b

        exp_kvs = Dict{Symbol,Any}(:a => 100.00001, :b => "2022-01-01")
        exp_obj = Foo3(100.00001, "2022-01-01")
        @test Serde.deser(Foo3, exp_kvs) == exp_obj
    end

    @testset "Case №4: Default value" begin
        struct Foo4
            value::Float64
            def1::Int64
            def2::Int64
        end

        Serde.default_value(::Type{Foo4}, ::Val{:def1}) = 100
        Serde.default_value(::Type{Foo4}, ::Val{:def2}) = 200

        exp_kvs = Dict{Symbol,Any}(:value => 100.00001)
        exp_obj = Foo4(100.00001, 100, 200)
        @test Serde.deser(Foo4, exp_kvs) == exp_obj
    end

    @testset "Case №5: Deserialization with nesting" begin
        struct Bar
            x::Int64
            y::Float64
        end

        struct Foo5
            f::Int64
            bar::Bar
        end

        exp_kvs = Dict{Symbol,Any}(:f => 10, :bar => Dict{Symbol,Any}(:x => 10, :y => 1000))
        exp_obj = Foo5(10, Bar(10, 1000))
        @test Serde.deser(Foo5, exp_kvs) == exp_obj
    end

    @testset "Case №6: Deserialization with nothing field" begin
        struct Foo6
            a::Float64
            b::Union{Int64,Nothing}
        end

        exp_kvs = Dict{Symbol,Any}(:a => 100.00001, :b => 100)
        exp_obj = Foo6(100.00001, 100)
        @test Serde.deser(Foo6, exp_kvs) == exp_obj
    end

    @testset "Case №7: Replace custom value" begin
        struct Foo7
            ts::Int64
            status::String
            err_code::String
            err_msg::String
        end

        Serde.custom_name(::Type{Foo7}, ::Val{:err_code}) = "err-code"
        Serde.custom_name(::Type{Foo7}, ::Val{:err_msg}) = "err-msg"

        exp_kvs = Dict{String,Any}(
            "ts" => 1671688821937,
            "status" => "error",
            "err-code" => "invalid parameter",
            "err-msg" => "invalid symbol",
        )
        exp_obj = Foo7(1671688821937, "error", "invalid parameter", "invalid symbol")
        @test Serde.deser(Foo7, exp_kvs) == exp_obj
    end

    @testset "Case №8: Deserialization with nothing" begin
        struct Foo8
            can_be_field::Union{Float64,Nothing}
            might_be_field::Union{Float64,Nothing}
        end

        exp_kvs = Dict{Symbol,Any}(:might_be_field => 2)
        exp_obj = Foo8(nothing, 2)
        @test Serde.deser(Foo8, exp_kvs) == exp_obj

        exp_kvs = Dict{Symbol,Any}()
        exp_obj = Foo8(nothing, nothing)
        @test Serde.deser(Foo8, exp_kvs) == exp_obj
    end

    @testset "Case №9: Deserialization with replace default value" begin
        struct Foo9
            limit::Int64
        end

        Serde.default_value(::Type{Foo9}, ::Val{:limit}) = 150

        exp_kvs = Dict{Symbol,Any}(:limit => 11)
        exp_obj = Foo9(11)
        @test Serde.deser(Foo9, exp_kvs) == exp_obj

        exp_kvs = Dict{Symbol,Any}()
        exp_obj = Foo9(150)
        @test Serde.deser(Foo9, exp_kvs) == exp_obj
    end

    @testset "Case №10: Deserialization with fill vector" begin
        struct Bar10
            weight::Float64
        end

        struct Foo10
            bananas::Vector{Bar10}
        end

        exp_kvs = Dict{Symbol,Any}(:bananas => fill(Dict{Symbol,Any}(:weight => 2), 3))
        exp_obj = Foo10(fill(Bar10(2), 3))
        @test Serde.deser(Foo10, exp_kvs).bananas == exp_obj.bananas
    end

    @testset "Case №11: Deserialization with deep nesting" begin
        struct Car11
            grams::Float64
        end

        struct Bar11
            weight::Car11
        end

        struct Foo11
            banana::Bar11
        end

        exp_kvs = Dict{Symbol,Any}(
            :banana => Dict{Symbol,Any}(:weight => Dict{Symbol,Any}(:grams => 2)),
        )
        exp_obj = Foo11(Bar11(Car11(2)))
        @test Serde.deser(Foo11, exp_kvs) == exp_obj
    end

    @testset "Case №12: Custom deserialization" begin
        struct Foo12
            distance::Float64
            when::DateTime
        end

        function Serde.deser(::Type{T}, data::S)::T where {T<:DateTime,S<:AbstractString}
            unix = tryparse(Float64, data)
            return unix2datetime(unix * 0.001)
        end

        exp_kvs = Dict{Symbol,Any}(:distance => "1444", :when => "1671688821937")
        exp_obj = Foo12(1444, DateTime("2022-12-22T06:00:21.937"))
        @test Serde.deser(Foo12, exp_kvs) == exp_obj
    end

    @testset "Case №13: Deserialization vector" begin
        struct Foo13
            a::Float64
            b::Date
        end

        (Serde.deser(::Type{T}, data::S)::T) where {T<:Date,S<:AbstractString} = Date(data)

        exp_kvs = [
            Dict{Symbol,Any}(:a => "100.00001", :b => "2022-01-01"),
            Dict{Symbol,Any}(:a => "100.00001", :b => "2022-01-01"),
            Dict{Symbol,Any}(:a => "100.00001", :b => "2022-01-01"),
        ]
        exp_obj = map(x -> Foo13(100.00001, Date("2022-01-01")), 1:3)
        @test Serde.deser(Vector{Foo13}, exp_kvs) == exp_obj
    end

    @testset "Case №14: Deserialization with replace all name" begin
        struct Foo14
            b_b::Union{String,Nothing}
            q_q::Union{String,Nothing}
            p_q::Union{Float64,Nothing}
            a_p::Union{Float64,Nothing}
        end

        (Serde.custom_name(::Type{Foo14}, ::Val{x})) where {x} =
            replace(string(x), "_" => "-")

        exp_kvs =
            Dict{String,Any}("b-b" => "25", "q-q" => "24", "p-q" => 23.0, "a-p" => 22.0)
        exp_obj = Foo14("25", "24", 23.0, 22.0)
        @test Serde.deser(Foo14, exp_kvs) == exp_obj
    end

    @testset "Case №15: Deserialization from vector" begin
        struct Foo15
            b::Union{String,Nothing}
            q::Union{String,Nothing}
            a::Union{Float64,Nothing}
            p::Union{Float64,Nothing}
        end

        exp_kvs = Vector{Any}(["25", "24", 23.0, 22.0])
        exp_obj = Foo15("25", "24", 23.0, 22.0)
        @test Serde.deser(Foo15, exp_kvs) == exp_obj
    end

    @testset "Case №16: Deserialization to vector of struct" begin
        struct Foo16
            fuel::Float64
        end

        exp_kvs = Dict{Symbol,Int64}[Dict{Symbol,Int64}(:fuel => 25)]
        exp_obj = Vector{Foo16}([Foo16(25.0)])
        @test Serde.deser(Vector{Foo16}, exp_kvs) == exp_obj
    end

    @testset "Case №17: Deserialization to dict" begin
        exp_kvs = Dict{Int64,String}(2 => "2", 3 => "3")
        exp_obj = Dict{String,Int64}("2" => 2, "3" => 3)
        @test Serde.deser(Dict{String,Int64}, exp_kvs) == exp_obj
    end

    @testset "Case №18: Deserialization type casting" begin
        struct Foo21
            a::Int64
            b::Int64
        end

        exp_kvs = Dict{Symbol,Any}(:a => 2, :b => "2")
        exp_obj = Foo21(2, 2)
        @test Serde.deser(Foo21, exp_kvs) == exp_obj
    end

    @testset "Case №19: Deserialization to dict of struct" begin
        struct Foo22
            a::Int64
            b::String
        end

        exp_kvs = Dict{String,Any}(
            "ABC" => Dict{String,String}("a" => "100", "b" => "hello"),
            "BBB" => Dict{String,String}("a" => "200", "b" => "hi"),
            "CCC" => Dict{String,Union{String,Int64}}("a" => 300, "b" => "holo"),
        )
        exp_obj = Dict{String,Foo22}(
            "BBB" => Foo22(200, "hi"),
            "CCC" => Foo22(300, "holo"),
            "ABC" => Foo22(100, "hello"),
        )
        @test Serde.deser(Dict{String,Foo22}, exp_kvs) == exp_obj
    end

    @testset "Case №20: Deserialization with inheritance" begin
        abstract type AbstractFoo23 end

        struct Foo23{I<:Int64} <: AbstractFoo23
            a::I
            b::String
        end

        exp_kvs = Dict{String,Any}(
            "ABC" => Dict{String,String}("a" => "100", "b" => "hello"),
            "BBB" => Dict{String,String}("a" => "200", "b" => "hi"),
            "CCC" => Dict{String,Union{String,Int64}}("a" => 300, "b" => "holo"),
        )
        exp_obj = Dict{String,Foo23}(
            "BBB" => Foo23(200, "hi"),
            "CCC" => Foo23(300, "holo"),
            "ABC" => Foo23(100, "hello"),
        )
        @test Serde.deser(Dict{String,Foo23}, exp_kvs) == exp_obj
    end

    @testset "Case №21: Empty parameters error" begin
        struct Foo24
            name::String
        end

        @test_throws "ParamError: parameter 'name::String' was not passed or has the value 'nothing'" Serde.deser(
            Foo24,
            Dict{String,Any}("name" => nothing),
        )
    end

    @testset "Case №22: Deserialization Enum" begin
        @enum Bar25 begin
            starting
            running
            stopping
            stopped
            restarting
        end

        struct Foo25
            n::String
            e::Bar25
        end

        exp_kvs = Dict{String,Any}("n" => "enum", "e" => 1)
        exp_obj = Foo25("enum", running)
        @test Serde.deser(Foo25, exp_kvs) == exp_obj

        exp_kvs = Dict{String,Any}("n" => "enum", "e" => :running)
        exp_obj = Foo25("enum", running)
        @test Serde.deser(Foo25, exp_kvs) == exp_obj
    end

    @testset "Case №23: Testing ClassType" begin
        struct Bar26
            a::Int64
        end

        struct Foo26
            a::Int64
            b::Bar26
        end

        @test Serde.ClassType(2) == Serde.PrimitiveType()
        @test Serde.ClassType("2") == Serde.PrimitiveType()
        @test Serde.ClassType(nothing) == Serde.NullType()
        @test Serde.ClassType(:a) == Serde.PrimitiveType()

        exp_kvs = Dict{Symbol,Any}(:a => 1, :b => Dict(:a => 1))
        exp_obj = Serde.deser(Foo26, exp_kvs)
        @test Serde.ClassType(exp_kvs) == Serde.DictType()
        @test Serde.ClassType(exp_obj) == Serde.CustomType()
        @test Serde.ClassType(exp_obj.a) == Serde.PrimitiveType()
        @test Serde.ClassType(exp_obj.b) == Serde.CustomType()
        @test Serde.ClassType(exp_obj.b.a) == Serde.PrimitiveType()
    end

    @testset "Case №24: Deserialization NamedTuple" begin
        struct NotTuple
            name::String
            not_tuple::NamedTuple
        end

        exp_kvs = Dict{String,Any}(
            "name" => "NamedTuple",
            "not_tuple" => Dict{String,Any}("a" => 10, "b" => 20),
        )
        exp_obj = Serde.deser(NotTuple, exp_kvs)

        @test exp_obj.name == "NamedTuple"
        @test exp_obj.not_tuple.a == 10
        @test exp_obj.not_tuple.b == 20
    end

    @testset "Case №25: Deserialization error wrong type casting" begin
        struct Foo27
            x::Union{Nothing,Int64}
        end

        @test_throws "WrongType: for 'Foo27' value 'test' has wrong type 'x::String', must be 'x::Union{Nothing, Int64}'" Serde.deser(
            Foo27,
            Dict{String,String}("x" => "test"),
        )
    end

    @testset "Case №26: Deserialization from Tuple" begin
        struct Foo29
            x::Int64
            b::String
        end

        exp_kvs = (x = 10, b = "test")
        exp_obj = Foo29(10, "test")
        @test Serde.deser(Foo29, exp_kvs) == exp_obj
    end

    @testset "Case №27: Error deserializing an empty string" begin
        struct Foo32
            x::Union{Nothing,Int64}
        end

        exp_kvs = Dict{String,String}("x" => "")
        @test_throws "WrongType: for 'Foo32' value '' has wrong type 'x::String', must be 'x::Union{Nothing, Int64}'" Serde.deser(
            Foo32,
            exp_kvs,
        )
    end

    @testset "Case №28: Deserializing an empty string" begin
        struct Foo33
            z::Int64
            x::Union{Nothing,Int64}
        end

        Serde.isempty(::Type{Foo33}, x::String)::Bool = x === ""

        exp_kvs = Dict{String,Union{String,Int64}}("z" => 100, "x" => "")
        exp_obj = Foo33(100, nothing)
        @test Serde.deser(Foo33, exp_kvs) == exp_obj
    end

    @testset "Case №29: Enum deserializing" begin
        @enum Direction begin
            Left
            Right
        end

        struct Journey
            fuel::Float64
            distance::Float64
            side::Direction
        end

        exp_kvs = Dict{String,Any}("distance" => 100, "fuel" => 150, "side" => :Right)
        exp_obj = Journey(150.0, 100.0, Right)
        @test Serde.deser(Journey, exp_kvs) == exp_obj

        exp_kvs = Dict{String,Any}("distance" => 100, "fuel" => 150, "side" => 1)
        exp_obj = Journey(150.0, 100.0, Right)
        @test Serde.deser(Journey, exp_kvs) == exp_obj

        exp_kvs = Dict{String,Any}("distance" => 100, "fuel" => 150, "side" => "Right")
        exp_obj = Journey(150.0, 100.0, Right)
        @test Serde.deser(Journey, exp_kvs) == exp_obj
    end

    @testset "Case №30: Deserializing missing and nothing" begin
        struct Foo35_1
            value::Union{Int64,Missing}
        end

        struct Foo35_2
            value::Union{Int64,Nothing}
        end

        exp_kvs = Dict{Symbol,Nothing}()
        exp_obj = Foo35_1(missing)
        @test Serde.deser(Foo35_1, exp_kvs) == exp_obj

        exp_kvs = Dict{Symbol,Int64}(:value => 2)
        exp_obj = Foo35_1(2)
        @test Serde.deser(Foo35_1, exp_kvs) == exp_obj

        exp_kvs = Dict{Symbol,Nothing}()
        exp_obj = Foo35_2(nothing)
        @test Serde.deser(Foo35_2, exp_kvs) == exp_obj

        exp_kvs = Dict{Symbol,Int64}(:value => 2)
        exp_obj = Foo35_2(2)
        @test Serde.deser(Foo35_2, exp_kvs) == exp_obj

        struct Foo35_3
            value::Missing
        end

        exp_kvs = Dict{String,Any}("value" => 100)
        @test_throws "WrongType: for 'Foo35_3' value '100' has wrong type 'value::Int64', must be 'value::Missing'" Serde.deser(
            Foo35_3,
            Dict{String,Any}("value" => 100),
        )
    end

    @testset "Case №31: Custom deserialization for concrete type" begin
        struct Foo36
            value::Float64
            expire_time::DateTime
            text::String
        end

        function Serde.deser(
            ::Type{Foo36},
            ::Type{T},
            x::String,
        )::DateTime where {T<:DateTime}
            return DateTime(x)
        end

        exp_kvs = Dict{String,Any}(
            "value" => 1000,
            "expire_time" => "2023-02-22T21:33:18.187",
            "text" => "4",
        )
        exp_obj = Foo36(1000.0, DateTime("2023-02-22T21:33:18.187"), "4")
        @test Serde.deser(Foo36, exp_kvs) == exp_obj
    end

    @testset "Case №32: Custom deserialization union with nothing" begin
        struct Foo37
            expire_time::Union{DateTime,Nothing}
        end

        function Serde.deser(
            ::Type{Foo37},
            ::Type{T},
            x::String,
        )::DateTime where {T<:DateTime}
            return DateTime(x)
        end

        exp_kvs = Dict{String,Any}("expire_time" => "2023-02-22T21:33:18.187")
        exp_obj = Foo37(DateTime("2023-02-22T21:33:18.187"))
        @test Serde.deser(Foo37, exp_kvs) == exp_obj

        exp_kvs = Dict{String,Any}()
        exp_obj = Foo37(nothing)
        @test Serde.deser(Foo37, exp_kvs) == exp_obj

        struct Foo38
            expire_time::Union{DateTime,Nothing}
        end

        exp_kvs = Dict{String,Any}("expire_time" => "2023-02-22T21:33:18.187")
        @test_throws "WrongType: for 'Foo38' value '2023-02-22T21:33:18.187' has wrong type 'expire_time::String', must be 'expire_time::Union{Nothing, DateTime}'" Serde.deser(
            Foo38,
            exp_kvs,
        )

        exp_kvs = Dict{String,Any}()
        exp_obj = Foo38(nothing)
        @test Serde.deser(Foo38, exp_kvs) == exp_obj
    end

    @testset "Case №33: Deserialization Vector{T} to Set{T}" begin
        struct Foo39
            a::Set{Int}
            b::Vector{Int}
            c::Set{String}
            d::Vector{String}
        end

        exp_str = """
        {
            "a": [1, 2, 3],
            "b": [1, 2, 3],
            "c": ["aaaa", "bbb", "ccc"],
            "d": ["ssss", "oooo", "dddd"]
        }
        """
        @test Serde.deser_json(Foo39, exp_str).a == Set([2, 3, 1])
        @test Serde.deser_json(Foo39, exp_str).b == [1, 2, 3]
        @test Serde.deser_json(Foo39, exp_str).c == Set(["bbb", "aaaa", "ccc"])
        @test Serde.deser_json(Foo39, exp_str).d == ["ssss", "oooo", "dddd"]

        struct Foo40
            q::Set{Int}
        end

        exp_kvs = Dict{String,Any}("q" => [2, 2, 2, 9])
        exp_obj = Foo40(Set([2, 9]))
        @test Serde.deser(Foo40, exp_kvs).q == exp_obj.q
    end

    @testset "Case №34: Deserialization AbstractString to AbstractString" begin
        struct Foo41
            a::SubString
        end

        exp_str = "{\"a\":100}"
        exp_obj = Foo41("100")
        @test Serde.deser_json(Foo41, exp_str) == exp_obj

        exp_str = "{\"a\":\"text\"}"
        exp_obj = Foo41("text")
        @test Serde.deser_json(Foo41, exp_str) == exp_obj

        struct Foo42
            a::String
        end

        exp_kvs = Dict{String,SubString}("a" => "text")
        exp_obj = Foo42("text")
        @test Serde.deser(Foo42, exp_kvs) == exp_obj
    end

    @testset "Case №35: Deserialization Number to Number" begin
        struct Foo43
            a::Float16
            b::Float32
            c::Float64
        end

        exp_str = "{\"a\":100,\"b\":100,\"c\":100}"
        exp_obj = Foo43(Float16(100.0), 100.0f0, 100.0)
        @test Serde.deser_json(Foo43, exp_str) == exp_obj

        struct Foo44
            a::Float16
        end

        exp_kvs = Dict{String,Float64}("a" => 2.1)
        exp_obj = Foo44(Float16(2.1))
        @test Serde.deser(Foo44, exp_kvs) == exp_obj
    end

    @testset "Case №36: Deserialization Vector with nothing to Struct" begin
        struct Foo45
            first_name::String
            second_name::Union{String,Nothing}
        end

        exp_str = "[\"Mark\"]"
        exp_obj = Foo45("Mark", nothing)
        @test Serde.deser_json(Foo45, exp_str) == exp_obj

        exp_str = "[\"Mark\", null]"
        exp_obj = Foo45("Mark", nothing)
        @test Serde.deser_json(Foo45, exp_str) == exp_obj
    end

    @testset "Case №37: Deserialization Number to Number" begin
        struct Message{P}
            method::AbstractString
            correlation_id::UInt64
            payload::P
        end

        exp_str = """ {"correlation_id":2,"method":"subscribe.status","payload":{}} """
        @test_throws "WrongType: for 'Message{Nothing}' got wrong type 'payload::Dict{String, Any}', must be 'payload::Nothing'" Serde.deser_json(
            Message{Nothing},
            exp_str,
        )
    end

    @testset "Case №38: Deserialization with missing field with Union{Nulltype,AnyType}" begin
        struct WithNothing
            y::Int64
            x::Union{String,Nothing}
        end
    
        @test Serde.deser(WithNothing, Dict("y" => 1, "x" => nothing)) == WithNothing(1, nothing)
        @test Serde.deser(WithNothing, Dict("y" => 2, "x" => missing)) == WithNothing(2, nothing)
    
        struct WithMissing
            y::Int64
            x::Union{String,Missing}
        end
    
        @test Serde.deser(WithMissing, Dict("y" => 3, "x" => nothing)) == WithMissing(3, missing)
        @test Serde.deser(WithMissing, Dict("y" => 4, "x" => missing)) == WithMissing(4, missing)
    end

    @testset "Case №39: Deserialization Tuple" begin
        struct DifferentTuples
            a::Tuple
            b::NTuple{2}
            c::Tuple{String,String,String}
            d::Tuple{String,Int64}
            e::Tuple{Float64,Int64}
        end

        exp_str = """
        {
            "a": ["1", "2", "3"],
            "b": ["1", "2"],
            "c": ["a", "b", "c"],
            "d": ["s", "1"],
            "e": ["0.01", "1"]
        }
        """
        @test Serde.deser_json(DifferentTuples, exp_str).a == Tuple(("1", "2", "3"))
        @test Serde.deser_json(DifferentTuples, exp_str).b == NTuple{2}(("1", "2"))
        @test Serde.deser_json(DifferentTuples, exp_str).c == Tuple{String,String,String}(("a", "b", "c"))
        @test Serde.deser_json(DifferentTuples, exp_str).d == Tuple{String,Int64}(("s", 1))
        @test Serde.deser_json(DifferentTuples, exp_str).e == Tuple{Float64,Int64}((0.01, 1))

        struct Tuples
            a::Tuple
            b::NTuple{3,Int64}
            c::Tuple{Int64,String,Int64}
        end

        exp_kvs = Dict{String,Any}(
            "a" => ("a", 1),
            "b" => (1, 2, 3),
            "c" => (1, 2, 3),
        )
        exp_obj = Tuples(Tuple(("a", 1)), NTuple{3,Int64}((1, 2, 3)), Tuple{Int64,String,Int64}((1, "2", 3)))
        @test Serde.deser(Tuples, exp_kvs).a == exp_obj.a
        @test Serde.deser(Tuples, exp_kvs).b == exp_obj.b
        @test Serde.deser(Tuples, exp_kvs).c == exp_obj.c

        exp_str2 = """
        [
            ["1", "2", "3"],
            ["1", "2"],
            ["a", "b", "c"],
            ["s", "1"],
            ["0.01", "1"]
        ]
        """
        @test Serde.deser_json(DifferentTuples, exp_str2).a == Tuple(("1", "2", "3"))
        @test Serde.deser_json(DifferentTuples, exp_str2).b == NTuple{2}(("1", "2"))
        @test Serde.deser_json(DifferentTuples, exp_str2).c == Tuple{String,String,String}(("a", "b", "c"))
        @test Serde.deser_json(DifferentTuples, exp_str2).d == Tuple{String,Int64}(("s", 1))
        @test Serde.deser_json(DifferentTuples, exp_str2).e == Tuple{Float64,Int64}((0.01, 1))
    end

    @testset "Case №40: Custom deserialization" begin
        struct SubType
            y::String
        end
        struct MyType
            x::SubType
        end
        json_str = """
            {
                "x":{
                    "y":{
                        "z":[1, 2, 3]
                    }
                }
            }
        """
        function Serde.deser(::Type{<:SubType}, ::Type{String}, x::AbstractDict)
            return "test"
        end
        exp_obj = MyType(SubType("test"))
        @test deser_json(MyType, json_str) == exp_obj

        json_str2 = """
            {
                "x":{
                    "y":[1, 2, 3]
                }
            }
        """
        function Serde.deser(::Type{<:SubType}, ::Type{String}, x::AbstractVector)
            return "test2"
        end
        exp_obj2 = MyType(SubType("test2"))
        @test deser_json(MyType, json_str2) == exp_obj2
    end

    @testset "Case №41: Deserialization Vector to Struct" begin
        struct Point
            x::Int
            y::Int
        end
        struct Line
            a::Point
            b::Point
        end
        struct Arrow
            label::String
            segments::Vector{Line}
            dashed::Bool
        end
        json_str = """{
            "label": "Hello",
            "segments": [
                 {"a": {"x": 1, "y": 1}, "b": {"x": 2, "y": 2}},
                 {"a": {"x": 2, "y": 2}, "b": {"x": 3, "y": 3}}
             ],
             "dashed": false
        }"""

        exp_obj = Arrow("Hello", Line[Line(Point(1, 1), Point(2, 2)), Line(Point(2, 2), Point(3, 3))], false)
        calc_obj = deser_json(Arrow, json_str)
        @test calc_obj.label == exp_obj.label
        @test calc_obj.segments[1] == exp_obj.segments[1]
        @test calc_obj.segments[2] == exp_obj.segments[2]
        @test calc_obj.dashed == exp_obj.dashed
    end

    @testset "Case №42: Deserialization Inf" begin
        exp_str1 = """{"bool":true,"number":101.101,"nan":null,"inf":null,"_missing":null,"_nothing":null}"""
        struct JsonBar3
            bool::Bool
            number::Float64
            nan::Nothing
            inf::Float64
            _missing::Missing
            _nothing::Nothing
        end

        @test_throws "ParamError: parameter 'inf::Float64' was not passed or has the value 'nothing'" deser_json(JsonBar3, exp_str1)

        exp_str2 = """{"bool":true,"number":101.101,"nan":null,"inf":"Inf","_missing":null,"_nothing":null}"""

        exp_obj = JsonBar3(true, 101.101, nothing, Inf, missing, nothing)
        @test deser_json(JsonBar3, exp_str2) == exp_obj
    end

    @testset "Case №43: Deserialization to Union" begin
        struct UnionType
            union_value::Union{Float64, String}
        end

        exp_str1 = "{\"union_value\":100.0}"
        exp_obj1 = UnionType(100.0)
        @test deser_json(UnionType, exp_str1) == exp_obj1

        exp_str2 = "{\"union_value\":\"100\"}"
        exp_obj2 = UnionType("100")
        @test deser_json(UnionType, exp_str2) == exp_obj2
    end

    @testset "Case №44: Deserialization from String and Vector{UInt8}" begin
        struct MyType44
            value1::Float64
            value2::String
        end

        exp_str = "{\"value1\":100.0, \"value2\": \"100\"}"
        exp_obj = MyType44(100.0, "100")
        @test deser_json(MyType44, exp_str) == exp_obj
        @test deser_json(MyType44, collect(codeunits(exp_str))) == exp_obj
    end

    @testset "Case №45: Deserialization to Nothing, Missing" begin
        @test isnothing(deser_json(Nothing, UInt8[]))
        @test isnothing(deser_json(Nothing, ""))
        @test ismissing(deser_json(Missing, UInt8[]))
        @test ismissing(deser_json(Missing, ""))
    end

    @testset "Case №46: JSON deserialization Nothing, Missing" begin
        exp_str = """ [null,null] """
        struct MyType46_1
            value1::Nothing
            value2::Missing
        end

        exp_obj = MyType46_1(nothing, missing)
        @test Serde.deser_json(MyType46_1, exp_str) == exp_obj

        exp_str = """ {"v":[null,null]} """;
        struct MyType46_2
            v::Vector{Nothing}
        end
        exp_obj = Serde.deser_json(MyType46_2, exp_str) 
        @time length(exp_obj.v) == 2
        @time all(isnothing, exp_obj.v)
    end

    @testset "Case №47: JSON deserialization Enum" begin
        @enum MyEnum a = 0
        
        struct MyType47 
            v::MyEnum
        end
        exp_obj = MyType47(MyEnum(0))

        exp_str1 = """ [ "a" ] """
        @test Serde.deser_json(MyType47, exp_str1) == exp_obj

        exp_str2 = """ [ 0 ] """
        @test Serde.deser_json(MyType47, exp_str2) == exp_obj

        exp_str3 = """ [ "0" ] """
        @test_throws "WrongType: for 'MyType47' got wrong type 'v::String', must be 'v::MyEnum'" Serde.deser_json(MyType47, exp_str3)
    end
end
