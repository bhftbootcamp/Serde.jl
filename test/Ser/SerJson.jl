# Ser/SerJson

@testset verbose = true "SerJson" begin
    @testset "Case №1: SerJson" begin
        struct JsonBar
            bool::Bool
            number::Float64
            nan::Float64
            inf::Float64
            _missing::Missing
            _nothing::Nothing
        end

        bar = JsonBar(true, 101.101, NaN, Inf, missing, nothing)

        @test Serde.to_json(bar) === """{"bool":true,"number":101.101,"nan":null,"inf":null,"_missing":null,"_nothing":null}"""
    end

    @testset "Case №2: Custom value" begin
        struct JsonFoo
            name::String
            date::Date
            bytes::Vector{UInt8}
        end

        Serde.SerJson.ser_value(h::JsonFoo, ::Val{:bytes})::String =
            String(view(h.bytes, 1:length(h.bytes)))

        fields1(::Type{JsonFoo}) = (:name,)
        fields2(::Type{JsonFoo}) = (:name, :date)

        foo = JsonFoo("test", Date("2022-01-01"), UInt8['t', 'e', 's', 't'])

        @test Serde.to_json(fields1, foo) === "{\"name\":\"test\"}"

        @test Serde.to_json(fields2, foo) === "{\"name\":\"test\",\"date\":\"2022-01-01\"}"

        @test Serde.to_json(foo) === "{\"name\":\"test\",\"date\":\"2022-01-01\",\"bytes\":[116,101,115,116]}"
    end

    @testset "Case №3: Annotation" begin
        struct JsonFoo2
            name::String
            foo::JsonFoo
            bar::JsonBar
        end

        fields1(::Type{JsonFoo2}) = (:foo, :bar)
        fields1(::Type{JsonFoo}) = (:date,)
        fields1(::Type{JsonBar}) = (:bool,)

        foo2 = JsonFoo2(
            "Custom",
            JsonFoo("test", Date("2022-01-01"), UInt8['t', 'e', 's', 't']),
            JsonBar(true, 101.101, NaN, Inf, missing, nothing),
        )

        @test Serde.to_json(fields1, foo2) === "{\"foo\":{\"date\":\"2022-01-01\"},\"bar\":{\"bool\":true}}"
    end

    @testset "Case №4: All basic types" begin
        struct JsonFoo4
            string::String
            int::Int64
            float::Float64
            bool::Bool
            miss::Missing
            noth::Nothing
            symbol::Symbol
            type::Type
            char::Char
        end

        foo4 = JsonFoo4("str", 42, 24.6, true, missing, nothing, :symb, Float64, 'e')

        @test Serde.to_json(foo4) === "{\"string\":\"str\",\"int\":42,\"float\":24.6,\"bool\":true,\"miss\":null,\"noth\":null,\"symbol\":\"symb\",\"type\":\"Float64\",\"char\":\"e\"}"
    end

    @testset "Case №5: All hard types" begin
        @enum Num begin
            num1
            num2
        end

        struct JsonFoo5
            vector::Vector{Any}
            dict::Dict{Any,Any}
            tuple::Tuple
            ntuple::NamedTuple
            pair::Pair
            timetype::TimeType
            enm::Num
            set::Set
        end

        foo5 = JsonFoo5(
            [1, "one", 3.0],
            Dict{Any,Any}(:a => 1, "b" => 2.0),
            (4, :b, "6"),
            (a = 1, b = 2),
            Pair(:e, 5),
            Date("2022-01-01"),
            num1,
            Set([1, 2]),
        )

        @test Serde.to_json(foo5) === """{"vector":[1,"one",3.0],"dict":{"a":1,"b":2.0},"tuple":[4,"b","6"],"ntuple":{"a":1,"b":2},"pair":{"e":5},"timetype":"2022-01-01","enm":"num1","set":[2,1]}"""
    end

    @testset "Case №6: Ignore null" begin
        abstract type AbstractQuery_6 end

        Base.@kwdef struct JsonFoo6_1 <: AbstractQuery_6
            x::String
            b::Union{String,Nothing} = nothing
        end

        Base.@kwdef struct JsonFoo6_2 <: AbstractQuery_6
            x::Union{String,Nothing}
            b::Union{String,Nothing} = nothing
            c::Union{Int64,Nothing} = nothing
        end

        (Serde.SerJson.ignore_null(::Type{A})::Bool) where {A<:AbstractQuery_6} = true

        foo1 = JsonFoo6_1(x = "test")
        foo2 = JsonFoo6_2(x = "test", c = 100)
        foo3 = JsonFoo6_2(x = nothing, c = 100)

        @test Serde.to_json(foo1) == "{\"x\":\"test\"}"
        @test Serde.to_json(foo2) == "{\"x\":\"test\",\"c\":100}"
        @test Serde.to_json(foo3) == "{\"c\":100}"
    end

    @testset "Case №7: Сustom type" begin
        struct JsonFoo7
            dt::DateTime
        end

        Serde.SerJson.ser_type(::Type{JsonFoo7}, x::DateTime) = string(datetime2unix(x))

        @test Serde.to_json(JsonFoo7(DateTime("2023-02-27T23:01:37.248"))) === "{\"dt\":\"1.677538897248e9\"}"
    end

    @testset "Case №8: PrettyJson" begin
        struct OneMoreObject
            bool::Bool
            empty::Nothing
        end

        struct SerJsonObject
            set::Set{String}
            pair::Pair
            datatype::DataType
            onemoreobject::OneMoreObject
        end

        struct SerJsonFoo1
            value::Int64
            text::String
            object::SerJsonObject
            array::Vector{Int64}
        end

        obj = SerJsonFoo1(
            34,
            "sertupe",
            SerJsonObject(
                Set(["a", "b"]),
                :a => 2,
                SerJsonFoo1,
                OneMoreObject(true, nothing),
            ),
            [1, 2, 3],
        )

        @test Serde.to_pretty_json(obj) == """{
                                             "value":34,
                                             "text":"sertupe",
                                             "object":{
                                               "set":[
                                                 "b",
                                                 "a"
                                               ],
                                               "pair":{
                                                 "a":2
                                               },
                                               "datatype":"SerJsonFoo1",
                                               "onemoreobject":{
                                                 "bool":true,
                                                 "empty":null
                                               }
                                             },
                                             "array":[
                                               1,
                                               2,
                                               3
                                             ]
                                           }"""
    end

    @testset "Case №9: Line break serialization" begin
        struct JsonFooLineBreak
            x::String
        end

        @test Serde.to_json(JsonFooLineBreak("""
            dsds
            dsds
            dssd"""),
        ) |> Serde.parse_json == Dict{String,Any}("x" => "dsds\ndsds\ndssd")

        struct JsonFooLineBreakSymbol
            x::Symbol
        end

        @test Serde.to_json(JsonFooLineBreakSymbol(Symbol("""
            dsds
            dsds
            dssd"""),
            ),
        ) |> Serde.parse_json == Dict{String,Any}("x" => "dsds\ndsds\ndssd")
    end

    @testset "Case №10: Long NamedTuple" begin
        @test Serde.to_json([
            (A = 10, B = "Hi", C = true, D = nothing),
            (A = 10, B = "Hi", C = true, D = nothing),
        ]) == "[{\"A\":10,\"B\":\"Hi\",\"C\":true,\"D\":null},{\"A\":10,\"B\":\"Hi\",\"C\":true,\"D\":null}]"
    end

    @testset "Case №11: Ignore field" begin
        struct IgnoreField
            str::String
            num::Int64
        end

        Serde.SerJson.ignore_field(::Type{IgnoreField}, ::Val{:str}) = true

        @test Serde.to_json(IgnoreField("test", 10)) == """{"num":10}"""

        struct IgnoreField2
            str::String
            num::Int64
        end

        Serde.SerJson.ignore_field(::Type{IgnoreField2}, ::Val{:num}, v) = v == 0

        @test Serde.to_json(IgnoreField2("test", 0)) == """{"str":"test"}"""
        @test Serde.to_json(IgnoreField2("test", 1)) == """{"str":"test","num":1}"""
    end
end
