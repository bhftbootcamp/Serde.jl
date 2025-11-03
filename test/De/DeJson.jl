# De/DeJson

@testset verbose = true "DeJson" begin
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
        @test deser_json(Foo39, exp_str).a == Set([2, 3, 1])
        @test deser_json(Foo39, exp_str).b == [1, 2, 3]
        @test deser_json(Foo39, exp_str).c == Set(["bbb", "aaaa", "ccc"])
        @test deser_json(Foo39, exp_str).d == ["ssss", "oooo", "dddd"]

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
        @test deser_json(Foo41, exp_str) == exp_obj

        exp_str = "{\"a\":\"text\"}"
        exp_obj = Foo41("text")
        @test deser_json(Foo41, exp_str) == exp_obj

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
        @test deser_json(Foo43, exp_str) == exp_obj

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
        @test deser_json(Foo45, exp_str) == exp_obj

        exp_str = "[\"Mark\", null]"
        exp_obj = Foo45("Mark", nothing)
        @test deser_json(Foo45, exp_str) == exp_obj
    end

    @testset "Case №37: Deserialization Number to Number" begin
        struct Message{P}
            method::AbstractString
            correlation_id::UInt64
            payload::P
        end

        exp_str = """ {"correlation_id":2,"method":"subscribe.status","payload":{}} """
        @test_throws "WrongType: for 'Message{Nothing}' value 'Dict{String, Any}()' has wrong type 'payload::Dict{String, Any}', must be 'payload::Nothing'" deser_json(
            Message{Nothing},
            exp_str,
        )
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
        @test deser_json(DifferentTuples, exp_str).a == Tuple(("1", "2", "3"))
        @test deser_json(DifferentTuples, exp_str).b == NTuple{2}(("1", "2"))
        @test deser_json(DifferentTuples, exp_str).c == Tuple{String,String,String}(("a", "b", "c"))
        @test deser_json(DifferentTuples, exp_str).d == Tuple{String,Int64}(("s", 1))
        @test deser_json(DifferentTuples, exp_str).e == Tuple{Float64,Int64}((0.01, 1))

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
    end

    @testset "Case №40: JSON custom deserialization" begin
        struct SubType
            y::String
        end

        struct MyType
            x::SubType
        end

        exp_str = """
        {
            "x": {
                "y": {
                    "z": [1, 2, 3]
                }
            }
        }
        """
        Serde.deser(::Type{<:SubType}, ::Type{String}, x::AbstractDict) = "test"
        exp_obj = MyType(SubType("test"))
        @test deser_json(MyType, exp_str) == exp_obj

        exp_str2 = """
        {
            "x": {
                "y": [1, 2, 3]
            }
        }
        """
        Serde.deser(::Type{<:SubType}, ::Type{String}, x::AbstractVector) = "test2"
        exp_obj2 = MyType(SubType("test2"))
        @test deser_json(MyType, exp_str2) == exp_obj2
    end

    @testset "Case №41: JSON deserialization Vector to Struct" begin
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

        exp_str = """
        {
            "label": "Hello",
            "segments": [
                {
                    "a": {"x": 1, "y": 1},
                    "b": {"x": 2, "y": 2}
                },
                {
                    "a": {"x": 2, "y": 2},
                    "b": {"x": 3, "y": 3}
                }
            ],
            "dashed": false
        }
        """

        exp_obj = Arrow(
            "Hello",
            Line[
                Line(Point(1, 1), Point(2, 2)),
                Line(Point(2, 2), Point(3, 3))
            ],
            false
        )

        calc_obj = deser_json(Arrow, exp_str)
        @test calc_obj.label == exp_obj.label
        @test calc_obj.segments[1] == exp_obj.segments[1]
        @test calc_obj.segments[2] == exp_obj.segments[2]
        @test calc_obj.dashed == exp_obj.dashed
    end

    @testset "Case №42: JSON deserialization Inf" begin
        struct JsonBar3
            bool::Bool
            number::Float64
            nan::Nothing
            inf::Float64
            var"missing"::Missing
            var"nothing"::Nothing
        end

        exp_str1 = """
        {
            "bool": true,
            "number": 101.101,
            "nan": null,
            "inf": null,
            "missing": null,
            "nothing": null
        }
        """
        @test_throws "ParamError: parameter 'inf::Float64' was not passed or has the value 'nothing'" deser_json(JsonBar3, exp_str1)

        exp_str2 = """
        {
            "bool": true,
            "number": 101.101,
            "nan": null,
            "inf": "Inf",
            "missing": null,
            "nothing": null
        }
        """
        exp_obj = JsonBar3(true, 101.101, nothing, Inf, missing, nothing)
        @test deser_json(JsonBar3, exp_str2) == exp_obj
    end

    @testset "Case №43: JSON deserialization to Union" begin
        struct UnionType
            union_value::Union{Float64,String}
        end

        exp_str1 = "{\"union_value\": 100.0}"
        exp_obj1 = UnionType(100.0)
        @test deser_json(UnionType, exp_str1) == exp_obj1

        exp_str2 = "{\"union_value\": \"100\"}"
        exp_obj2 = UnionType("100")
        @test deser_json(UnionType, exp_str2) == exp_obj2
    end

    @testset "Case №44: JSON deserialization from String and Vector{UInt8}" begin
        struct MyType44
            value1::Float64
            value2::String
        end

        exp_str = """
        {
            "value1": 100.0,
            "value2": "100"
        }
        """
        exp_obj = MyType44(100.0, "100")
        @test deser_json(MyType44, exp_str) == exp_obj
        @test deser_json(MyType44, collect(codeunits(exp_str))) == exp_obj
    end

    @testset "Case №45: JSON deserialization to Nothing, Missing" begin
        @test isnothing(deser_json(Nothing, UInt8[]))
        @test isnothing(deser_json(Nothing, ""))
        @test ismissing(deser_json(Missing, UInt8[]))
        @test ismissing(deser_json(Missing, ""))
    end

    @testset "Case №46: JSON deserialization Nothing, Missing" begin
        struct MyType46_1
            value1::Nothing
            value2::Missing
        end

        exp_str = """
        [
            null,
            null
        ]
        """
        exp_obj = MyType46_1(nothing, missing)
        @test deser_json(MyType46_1, exp_str) == exp_obj

        struct MyType46_2
            v::Vector{Nothing}
        end

        exp_str = """
        {
            "v": [null, null]
        }
        """
        exp_obj = deser_json(MyType46_2, exp_str)
        @test length(exp_obj.v) == 2
        @test all(isnothing, exp_obj.v)
    end

    @testset "Case №47: JSON deserialization Enum" begin
        @enum MyEnum a = 0

        struct MyType47
            v::MyEnum
        end
        exp_obj = MyType47(MyEnum(0))

        exp_str1 = "[\"a\"]"
        @test deser_json(MyType47, exp_str1) == exp_obj

        exp_str11 = "{\"v\": \"a\"}"
        @test deser_json(MyType47, exp_str11) == exp_obj

        exp_str2 = "[0]"
        @test deser_json(MyType47, exp_str2) == exp_obj
        exp_str22 = "{\"v\": 0}"
        @test deser_json(MyType47, exp_str22) == exp_obj

        exp_str3 = "[\"0\"]"
        @test_throws "WrongType: for 'MyType47' value '0' has wrong type 'v::String', must be 'v::MyEnum'" deser_json(MyType47, exp_str3)
        exp_str33 = "{\"v\": \"0\"}"
        @test_throws "WrongType: for 'MyType47' value '0' has wrong type 'v::String', must be 'v::MyEnum'" deser_json(MyType47, exp_str33)
    end

    @testset "Case №48: JSON deserialization NamedTuple" begin
        struct MyType48_1
            count::NamedTuple
        end

        exp_str1 = "{\"count\": {\"a\": \"1\", \"b\": \"2\", \"c\": \"3\"}}"
        exp_obj1 = MyType48_1((a = "1", b = "2", c = "3"))
        @test deser_json(MyType48_1, exp_str1) == exp_obj1

        struct MyType48_2
            count::NamedTuple{(:a, :b),Tuple{Int64,String}}
        end

        exp_str2 = "{\"count\": {\"a\": 1, \"b\": \"2\"}}"
        exp_obj2 = MyType48_2((a = 1, b = "2"))
        @test deser_json(MyType48_2, exp_str2) == exp_obj2
    end

    @testset "Case №49: JSON deserialization Set" begin
        struct MyType49
            count::Set{Number}
        end

        exp_str = "{\"count\": [1, 2, 3.0]}"
        exp_obj = MyType49(Set(Number[1, 2, 3.0]))
        @test deser_json(MyType49, exp_str).count == exp_obj.count
    end
end
