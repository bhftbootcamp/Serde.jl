# deser

using Serde
using Test, Dates

@testset verbose = true "De" begin
    @testset "Case №1: Simple deserialization" begin
        struct Foo
            a::Int64
            b::Int64
        end

        @test let
            h = Dict{Symbol,Int64}(:a => 100, :b => 300)
            Serde.deser(Foo, h) == Foo(100, 300)
        end

        @test let
            h = Dict{String,Int64}("a" => 100, "b" => 300)
            Serde.deser(Foo, h) == Foo(100, 300)
        end

        @test_throws "ParamError: parameter 'b::Int64' was not passed or has the value 'null'" let
            h = Dict{Symbol,Int64}(:a => 100)
            Serde.deser(Foo, h)
        end

        @test_throws "ParamError: parameter 'a::Int64' was not passed or has the value 'null'" let
            h = Dict{Symbol,Int64}(:b => 100)
            Serde.deser(Foo, h)
        end

        @test_throws "WrongType: for 'Foo' value '100.00001' has wrong type 'a::Float64', must be 'a::Int64'" let
            h = Dict{String,Real}("a" => 100.00001, "b" => 300)
            Serde.deser(Foo, h)
        end
    end

    @testset "Case №2: Deserialization with type casting" begin
        struct Foo2
            a::Int64
            b::Float64
        end

        @test let
            h = Dict{Symbol,Any}(:a => 100, :b => "300.0001")
            Serde.deser(Foo2, h) == Foo2(100, 300.0001)
        end

        @test let
            h = Dict{String,Any}("a" => 100, "b" => "300")
            Serde.deser(Foo2, h) == Foo2(100, 300)
        end
    end

    @testset "Case №3: Custom name" begin
        struct Foo3
            a::Float64
            other_name::String
        end

        function Serde.custom_name(::Type{Foo3}, ::Val{:other_name})
            return :b
        end

        @test let
            h = Dict{Symbol,Any}(:a => "100.00001", :b => "2022-01-01")
            Serde.deser(Foo3, h) == Foo3(100.00001, "2022-01-01")
        end
    end

    @testset "Case №4: Default value" begin
        struct Foo4
            value::Float64
            def1::Int64
            def2::Int64
        end

        function Serde.default_value(::Type{Foo4}, ::Val{:def1})
            return 100
        end

        function Serde.default_value(::Type{Foo4}, ::Val{:def2})
            return 200
        end

        @test let
            h = Dict{Symbol,Any}(:value => "100.00001")
            Serde.deser(Foo4, h) == Foo4(100.00001, 100, 200)
        end
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

        @test let
            h = Dict{Symbol,Any}(:f => 10, :bar => Dict{Symbol,Any}(:x => 10, :y => 1000))
            Serde.deser(Foo5, h) == Foo5(10, Bar(10, 1000))
        end
    end

    @testset "Case №6: Deserialization with nothing field" begin
        struct Foo6
            a::Float64
            b::Union{Int64,Nothing}
        end

        @test let
            h = Dict{Symbol,Any}(:a => "100.00001")
            Serde.deser(Foo6, h) == Foo6(100.00001, nothing)
        end
    end

    @testset "Case №7: Replace custom value" begin
        struct Foo7
            ts::Int64
            status::String
            err_code::String
            err_msg::String
        end

        function Serde.custom_name(::Type{Foo7}, ::Val{:err_code})
            return "err-code"
        end

        function Serde.custom_name(::Type{Foo7}, ::Val{:err_msg})
            return "err-msg"
        end

        @test let
            h = Dict{String,Any}(
                "status" => "error",
                "err-code" => "invalid-parameter",
                "err-msg" => "invalid symbol",
                "ts" => 1671688821937,
            )

            Serde.deser(Foo7, h) ==
            Foo7(1671688821937, "error", "invalid-parameter", "invalid symbol")
        end
    end

    @testset "Case №8: Deserialization with nothing" begin
        struct Foo8
            askMultiplierUp::Union{Float64,Nothing}
            maxQty::Union{Float64,Nothing}
        end

        @test let
            h = Dict{Symbol,Any}(:maxQty => 2)
            Serde.deser(Foo8, h) == Foo8(nothing, 2)
        end

        @test let
            h = Dict{Symbol,Any}()
            Serde.deser(Foo8, h) == Foo8(nothing, nothing)
        end
    end

    @testset "Case №9: Deserialization with replace default value" begin
        struct Foo9
            limit::Int64
        end

        function Serde.default_value(::Type{Foo9}, ::Val{:limit})
            return 150
        end

        @test let
            h = Dict{Symbol,Any}(:limit => 11)
            Serde.deser(Foo9, h) == Foo9(11)
        end

        @test let
            h = Dict{Symbol,Any}()
            Serde.deser(Foo9, h) == Foo9(150)
        end
    end

    @testset "Case №10: Deserialization with fill vector" begin
        struct Bar10
            price::Float64
        end

        struct Foo10
            asks::Vector{Bar10}
        end

        @test let
            b = Dict{Symbol,Any}(:price => 2)
            h = Dict{Symbol,Any}(:asks => fill(b, 3))
            Serde.deser(Foo10, h).asks == Foo10(fill(Bar10(2), 3)).asks
        end
    end

    @testset "Case №11: Deserialization with deep nesting" begin
        struct Car11
            price::Float64
        end

        struct Bar11
            level::Car11
        end

        struct Foo11
            asks::Bar11
        end

        @test let
            c = Dict{Symbol,Any}(:price => 2)
            b = Dict{Symbol,Any}(:level => c)
            h = Dict{Symbol,Any}(:asks => b)
            Serde.deser(Foo11, h) == Foo11(Bar11(Car11(2)))
        end
    end

    @testset "Case №12: Custom deserialization" begin
        struct Foo12
            high24h::Float64
            listTime::DateTime
        end

        function Serde.deser(::Type{T}, data::S)::T where {T<:DateTime,S<:AbstractString}
            unix = tryparse(Float64, data)
            return unix2datetime(unix * 0.001)
        end

        @test let
            h = Dict{Symbol,Any}(:high24h => "1444", :listTime => "1671688821937")
            Serde.deser(Foo12, h) == Foo12(1444, DateTime("2022-12-22T06:00:21.937"))
        end
    end

    @testset "Case №13: Deserialization vector" begin
        struct Foo13
            a::Float64
            b::Date
        end

        function Serde.deser(::Type{T}, data::S)::T where {T<:Date,S<:AbstractString}
            return Date(data)
        end

        @test let
            h = [
                Dict{Symbol,Any}(:a => "100.00001", :b => "2022-01-01"),
                Dict{Symbol,Any}(:a => "100.00001", :b => "2022-01-01"),
                Dict{Symbol,Any}(:a => "100.00001", :b => "2022-01-01"),
                #...
            ]

            Serde.deser(Vector{Foo13}, h) == map(x -> Foo13(100.00001, Date("2022-01-01")), 1:3)
        end
    end

    @testset "Case №14: Deserialization with replace all name" begin
        struct Foo14
            b_b::Union{String,Nothing}
            q_q::Union{String,Nothing}
            p_q::Union{Float64,Nothing}
            a_p::Union{Float64,Nothing}
        end

        function Serde.custom_name(::Type{Foo14}, ::Val{x}) where {x}
            return replace(string(x), "_" => "-")
        end

        @test let
            h = Dict{String,Any}("b-b" => "25", "q-q" => "24", "p-q" => "23", "a-p" => "22")
            Serde.deser(Foo14, h) == Foo14("25", "24", 23.0, 22.0)
        end
    end

    @testset "Case №15: Deserialization from vector" begin
        struct Foo15
            b::Union{String,Nothing}
            q::Union{String,Nothing}
            a::Union{Float64,Nothing}
            p::Union{Float64,Nothing}
        end

        @test let
            h = Vector{Any}(["25", "24", 23.0, 22.0])
            Serde.deser(Foo15, h) == Foo15("25", "24", 23.0, 22.0)
        end
    end

    @testset "Case №16: Deserialization to vector of struct" begin
        struct Foo16
            price::Float64
        end

        @test let
            h = Dict{Symbol,Int64}[Dict{Symbol,Int64}(:price => 25)]
            Serde.deser(Vector{Foo16}, h) == Vector{Foo16}([Foo16(25.0)])
        end
    end

    @testset "Case №17: Deserialization to dict" begin
        @test let
            h = Dict{Int64,String}(2 => "2", 3 => "3")

            result = Dict{String,Int64}("2" => 2, "3" => 3)

            Serde.deser(Dict{String,Int64}, h) == result
        end
    end

    @testset "Case №18: Deserialization type casting" begin
        struct Foo21
            a::Int64
            b::Int64
        end

        @test let
            h = Dict{Symbol,Any}(:a => 2, :b => "2")
            Serde.deser(Foo21, h) == Foo21(2, 2)
        end
    end

    @testset "Case №19: Deserialization to dict of struct" begin
        struct Foo22
            a::Int64
            b::String
        end

        @test let
            h = Dict{String,Any}(
                "ABC" => Dict{String,String}("a" => "100", "b" => "hello"),
                "BBB" => Dict{String,String}("a" => "200", "b" => "hi"),
                "CCC" => Dict{String,Union{String,Int64}}("a" => 300, "b" => "holo"),
            )

            result = Dict{String,Foo22}(
                "BBB" => Foo22(200, "hi"),
                "CCC" => Foo22(300, "holo"),
                "ABC" => Foo22(100, "hello"),
            )

            Serde.deser(Dict{String,Foo22}, h) == result
        end
    end

    @testset "Case №20: Deserialization with inheritance" begin
        abstract type AbstractFoo23 end

        struct Foo23{I<:Int64} <: AbstractFoo23
            a::I
            b::String
        end

        @test let
            h = Dict{String,Any}(
                "ABC" => Dict{String,String}("a" => "100", "b" => "hello"),
                "BBB" => Dict{String,String}("a" => "200", "b" => "hi"),
                "CCC" => Dict{String,Union{String,Int64}}("a" => 300, "b" => "holo"),
            )

            result = Dict{String,Foo23}(
                "BBB" => Foo23(200, "hi"),
                "CCC" => Foo23(300, "holo"),
                "ABC" => Foo23(100, "hello"),
            )

            Serde.deser(Dict{String,Foo23}, h) == result
        end
    end

    @testset "Case №21: Empty parameters error" begin
        struct Foo24
            name::String
        end

        @test_throws "ParamError: parameter 'name::String' was not passed or has the value 'null'" let
            Serde.deser(Foo24, Dict{String,Any}())
        end
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

        @test let
            h = Dict{String,Any}("n" => "enum", "e" => 1)
            Serde.deser(Foo25, h) == Foo25("enum", running)
        end

        @test let
            h = Dict{String,Any}("n" => "enum", "e" => :running)
            Serde.deser(Foo25, h) == Foo25("enum", running)
        end
    end

    @testset "Case №23: Testing ClassType" begin
        struct Bar26
            a::Int64
        end

        struct Foo26
            a::Int64
            b::Bar26
        end

        let
            @test Serde.ClassType(2) == Serde.PrimitiveType()
            @test Serde.ClassType("2") == Serde.PrimitiveType()
            @test Serde.ClassType(nothing) == Serde.NullType()
            @test Serde.ClassType(:a) == Serde.PrimitiveType()
        end

        let
            h = Dict{Symbol,Any}(:a => 1, :b => Dict(:a => 1))
            foo = Serde.deser(Foo26, h)

            @test Serde.ClassType(h) == Serde.DictType()
            @test Serde.ClassType(foo) == Serde.CustomType()
            @test Serde.ClassType(foo.a) == Serde.PrimitiveType()
            @test Serde.ClassType(foo.b) == Serde.CustomType()
            @test Serde.ClassType(foo.b.a) == Serde.PrimitiveType()
        end
    end

    @testset "Case №24: Deserialization NamedTuple" begin
        struct NotTuple
            name::String
            nt::NamedTuple
        end

        let
            h = Dict{String,Any}(
                "name" => "NamedTuple",
                "nt" => Dict{String,Any}("a" => 10, "b" => 20),
            )

            nt = Serde.deser(NotTuple, h)

            @test nt.name == "NamedTuple"
            @test nt.nt.a == 10
            @test nt.nt.b == 20
        end
    end

    @testset "Case №25: Deserialization error wrong type casting" begin
        struct Foo27
            x::Union{Nothing,Int64}
        end

        @test_throws "WrongType: for 'Foo27' value 'test' has wrong type 'x::String', must be 'x::Union{Nothing, Int64}'" let
            Serde.deser(Foo27, Dict{String,String}("x" => "test"))
        end
    end

    @testset "Case №26: Deserialization from Tuple" begin
        struct Foo29
            x::Int64
            b::String
        end

        @test let
            Serde.deser(Foo29, (x = 10, b = "test")) == Foo29(10, "test")
        end
    end

    @testset "Case №27: Error deserializing an empty string" begin
        struct Foo32
            x::Union{Nothing,Int64}
        end

        h = Dict{String,String}("x" => "")

        @test_throws "WrongType: for 'Foo32' value '' has wrong type 'x::String', must be 'x::Union{Nothing, Int64}'" Serde.deser(
            Foo32,
            h,
        )
    end

    @testset "Case №28: Deserializing an empty string" begin
        struct Foo33
            z::Int64
            x::Union{Nothing,Int64}
        end

        function Serde.isempty(::Type{Foo33}, x)::Bool
            return x === "" ? true : false
        end

        h = Dict{String,Union{String,Int64}}("z" => 100, "x" => "")

        @test Serde.deser(Foo33, h) == Foo33(100, nothing)
    end

    @testset "Case №29: Enum deserializing" begin
        @enum BuySell begin
            Buy
            Sell
        end

        struct Trade
            price::Float64
            amount::Float64
            side::BuySell
        end

        @test Serde.deser(
            Trade,
            Dict{String,Any}("amount" => 100, "price" => 150, "side" => :Sell),
        ) == Trade(150.0, 100.0, Sell)

        @test Serde.deser(
            Trade,
            Dict{String,Any}("amount" => 100, "price" => 150, "side" => 1),
        ) == Trade(150.0, 100.0, Sell)

        @test Serde.deser(
            Trade,
            Dict{String,Any}("amount" => 100, "price" => 150, "side" => "1"),
        ) == Trade(150.0, 100.0, Sell)

        @test Serde.deser(
            Trade,
            Dict{String,Any}("amount" => 100, "price" => 150, "side" => "Sell"),
        ) == Trade(150.0, 100.0, Sell)
    end

    @testset "Case №30: Deserializing missing and nothing" begin
        struct Foo35_1
            value::Union{Int64,Missing}
        end

        struct Foo35_2
            value::Union{Int64,Nothing}
        end

        @test Serde.deser(Foo35_1, Dict{Symbol,Nothing}()) == Foo35_1(missing)

        @test Serde.deser(Foo35_1, Dict{Symbol,Int64}(:value => 2)) == Foo35_1(2)

        @test Serde.deser(Foo35_2, Dict{Symbol,Nothing}()) == Foo35_2(nothing)

        @test Serde.deser(Foo35_2, Dict{Symbol,Int64}(:value => 2)) == Foo35_2(2)

        @test_throws "WrongType: for 'Foo35_3' value '100' has wrong type 'value::Int64', must be 'value::Missing'" let
            struct Foo35_3
                value::Missing
            end

            Serde.deser(Foo35_3, Dict{String,Any}("value" => 100))
        end
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

        h = Dict{String,Any}(
            "value" => 1000,
            "expire_time" => "2023-02-22T21:33:18.187",
            "text" => "4",
        )

        @test Serde.deser(Foo36, h) == Foo36(1000.0, DateTime("2023-02-22T21:33:18.187"), "4")
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

        h = Dict{String,Any}("expire_time" => "2023-02-22T21:33:18.187")

        @test Serde.deser(Foo37, h) == Foo37(DateTime("2023-02-22T21:33:18.187"))
        @test Serde.deser(Foo37, Dict{String,Any}()) == Foo37(nothing)

        struct Foo38
            expire_time::Union{DateTime,Nothing}
        end

        @test_throws "WrongType: for 'Foo38' value '2023-02-22T21:33:18.187' has wrong type 'expire_time::String', must be 'expire_time::Union{Nothing, DateTime}'" let
            Serde.deser(Foo38, h) == Foo37(DateTime("2023-02-22T21:33:18.187"))
        end

        @test Serde.deser(Foo38, Dict{String,Any}()) == Foo38(nothing)
    end
    using Serde

    @testset "Case №33: Deserialization Vector{T} to Set{T}" begin
        struct Foo39
            a::Set{Int}
            b::Vector{Int}
            c::Set{String}
            d::Vector{String}
        end
        jsn = """
        {
            "a": [1, 2, 3],
            "b": [1, 2, 3],
            "c": ["aaaa", "bbb", "ccc"],
            "d": ["ssss", "oooo", "dddd"]
        }
        """
        res = Serde.deser_json(Foo39, jsn)
        @test res.a == Set([2, 3, 1])
        @test res.b == [1, 2, 3]
        @test res.c == Set(["bbb", "aaaa", "ccc"])
        @test res.d == ["ssss", "oooo", "dddd"]

        struct Foo40
            q::Set{Int}
        end

        @test Serde.deser(Foo40, Dict("q" => (2, 2, 2, 9))).q == Set([2, 9])
    end

    @testset "Case №34: Deserialization AbstractString to AbstractString" begin
        struct Foo41
            a::SubString
        end

        @test Foo41("100") == Serde.deser_json(Foo41, "{\"a\":100}")
        @test Foo41("text") == Serde.deser_json(Foo41, "{\"a\":\"text\"}")

        struct Foo42
            a::String
        end

        @test Foo42("text") == Serde.deser(Foo42, Dict{String,SubString}("a" => "text"))
    end

    @testset "Case №35: Deserialization Number to Number" begin
        struct Foo43
            a::Float16
            b::Float32
            c::Float64
        end

        @test Foo43(Float16(100.0), 100.0f0, 100.0) ==
              Serde.deser_json(Foo43, "{\"a\":100,\"b\":100,\"c\":100}")

        struct Foo44
            a::Float16
        end

        @test Foo44(2.1) == Serde.deser(Foo44, Dict{String,Float64}("a" => 2.1))
    end

    @testset "Case №36: Deserialization Vector with nothing to Struct" begin
        struct Foo45
            first_name::String
            second_name::Union{String,Nothing}
        end

        @test Foo45("Mark", nothing) == Serde.deser_json(Foo45, "[\"Mark\"]")
        @test Foo45("Mark", nothing) == Serde.deser_json(Foo45, "[\"Mark\", null]")
    end

    @testset "Case №37: Deserialization Number to Number" begin
        struct Message{P}
            method::AbstractString
            correlation_id::UInt64
            payload::P
        end

        data = """ {"correlation_id":2,"method":"subscribe.status","payload":{}} """

        @test_throws "WrongType: for 'Message{Nothing}' value 'Dict{String, Any}()' has wrong type 'payload::Dict{String, Any}', must be 'payload::Nothing'" let
            Serde.deser_json(Message{Nothing}, data)
        end
    end
end
