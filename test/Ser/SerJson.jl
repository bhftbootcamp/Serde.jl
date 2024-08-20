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

        exp_obj = JsonBar(true, 101.101, NaN, Inf, missing, nothing)
        exp_str = """{"bool":true,"number":101.101,"nan":null,"inf":null,"_missing":null,"_nothing":null}"""
        @test Serde.to_json(exp_obj) === exp_str
    end

    @testset "Case №2: Custom value" begin
        struct JsonFoo
            name::String
            date::Date
            bytes::Vector{UInt8}
        end

        Serde.SerJson.ser_value(::Type{JsonFoo}, ::Val{:bytes}, v::Vector{UInt8})::String = String(view(v, 1:length(v)))

        fields_1(::Type{JsonFoo}) = (:name,)
        fields_2(::Type{JsonFoo}) = (:name, :date)

        exp_obj = JsonFoo("test", Date("2022-01-01"), UInt8['t', 'e', 's', 't'])

        exp_str = "{\"name\":\"test\"}"
        @test Serde.to_json(fields_1, exp_obj) === exp_str

        exp_str = "{\"name\":\"test\",\"date\":\"2022-01-01\"}"
        @test Serde.to_json(fields_2, exp_obj) === exp_str

        exp_str = "{\"name\":\"test\",\"date\":\"2022-01-01\",\"bytes\":\"test\"}"
        @test Serde.to_json(exp_obj) === exp_str
    end

    @testset "Case №3: Annotation" begin
        struct JsonFoo2
            name::String
            foo::JsonFoo
            bar::JsonBar
        end

        fields_1(::Type{JsonFoo2}) = (:foo, :bar)
        fields_1(::Type{JsonFoo}) = (:date,)
        fields_1(::Type{JsonBar}) = (:bool,)

        exp_obj = JsonFoo2(
            "Custom",
            JsonFoo("test", Date("2022-01-01"), UInt8['t', 'e', 's', 't']),
            JsonBar(true, 101.101, NaN, Inf, missing, nothing),
        )
        exp_str = "{\"foo\":{\"date\":\"2022-01-01\"},\"bar\":{\"bool\":true}}"
        @test Serde.to_json(fields_1, exp_obj) === exp_str

        exp_obj = (a = 1, b = "asdf", c = [3, 2, 1])
        exp_str = "{\"b\":\"asdf\"}"
        @test Serde.to_json(x -> (:b,), exp_obj) === exp_str
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

        exp_obj = JsonFoo4("str", 42, 24.6, true, missing, nothing, :symb, Float64, 'e')
        exp_str = """{"string":"str","int":42,"float":24.6,"bool":true,"miss":null,"noth":null,"symbol":"symb","type":"Float64","char":"e"}"""
        @test Serde.to_json(exp_obj) === exp_str
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
            uuid::UUID
        end

        exp_obj = JsonFoo5(
            [1, "one", 3.0],
            Dict{Any,Any}(:a => 1, "b" => 2.0),
            (4, :b, "6"),
            (a = 1, b = 2),
            Pair(:e, 5),
            Date("2022-01-01"),
            num1,
            Set([1, 2]),
            UUID("764c061c-fdf6-4149-9924-d3b4b3e416d2"),
        )
        exp_str = """{"vector":[1,"one",3.0],"dict":{"a":1,"b":2.0},"tuple":[4,"b","6"],\
        "ntuple":{"a":1,"b":2},"pair":{"e":5},"timetype":"2022-01-01","enm":"num1","set":[2,1],\
        "uuid":"764c061c-fdf6-4149-9924-d3b4b3e416d2"}"""
        @test Serde.to_json(exp_obj) === exp_str
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

        (Serde.SerJson.ser_ignore_null(::Type{A})::Bool) where {A<:AbstractQuery_6} = true

        exp_obj = JsonFoo6_1(x = "test")
        exp_str = "{\"x\":\"test\"}"
        @test Serde.to_json(exp_obj) === exp_str

        exp_obj = JsonFoo6_2(x = "test", c = 100)
        exp_str = "{\"x\":\"test\",\"c\":100}"
        @test Serde.to_json(exp_obj) === exp_str

        exp_obj = JsonFoo6_2(x = nothing, c = 100)
        exp_str = "{\"c\":100}"
        @test Serde.to_json(exp_obj) === exp_str
    end

    @testset "Case №7: Сustom type" begin
        struct JsonFoo7
            dt::DateTime
        end

        Serde.SerJson.ser_type(::Type{JsonFoo7}, x::DateTime) = string(datetime2unix(x))

        exp_obj = JsonFoo7(DateTime("2023-02-27T23:01:37.248"))
        exp_str = "{\"dt\":\"1.677538897248e9\"}"
        @test Serde.to_json(exp_obj) === exp_str
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
            matrix::Matrix{Float64}
        end

        obj = SerJsonFoo1(
            34,
            "sertupe",
            SerJsonObject(Set(["a", "b"]), :a => 2, SerJsonFoo1, OneMoreObject(true, nothing)),
            [1, 2, 3],
            ones(2, 3)
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
                                             ],
                                             "matrix":[
                                               [
                                                 1.0,
                                                 1.0
                                               ],
                                               [
                                                 1.0,
                                                 1.0
                                               ],
                                               [
                                                 1.0,
                                                 1.0
                                               ]
                                             ]
                                           }"""
    end

    @testset "Case №9: Line break serialization" begin
        struct JsonFooLineBreak
            x::String
        end

        exp_obj = Dict{String,Any}("x" => "dsds\ndsds\ndssd")
        exp_str = """
            dsds
            dsds
            dssd"""
        @test Serde.to_json(JsonFooLineBreak(exp_str)) |> Serde.parse_json == exp_obj

        struct JsonFooLineBreakSymbol
            x::Symbol
        end

        exp_obj = Dict{String,Any}("x" => "dsds\ndsds\ndssd")
        exp_str = """
            dsds
            dsds
            dssd"""
        @test Serde.to_json(JsonFooLineBreakSymbol(Symbol(exp_str))) |> Serde.parse_json == exp_obj
    end

    @testset "Case №10: Long NamedTuple" begin
        exp_obj = [(A = 10, B = "Hi", C = true, D = nothing), (A = 10, B = "Hi", C = true, D = nothing)]
        exp_str = "[{\"A\":10,\"B\":\"Hi\",\"C\":true,\"D\":null},{\"A\":10,\"B\":\"Hi\",\"C\":true,\"D\":null}]"
        @test Serde.to_json(exp_obj) == exp_str
    end

    @testset "Case №11: Ignore field" begin
        struct IgnoreField
            str::String
            num::Int64
        end

        Serde.SerJson.ser_ignore_field(::Type{IgnoreField}, ::Val{:str}) = true

        exp_obj = IgnoreField("test", 10)
        exp_str = """{"num":10}"""
        @test Serde.to_json(exp_obj) == exp_str

        struct IgnoreField2
            str::String
            num::Int64
        end

        Serde.SerJson.ser_ignore_field(::Type{IgnoreField2}, ::Val{:num}, v) = v == 0

        exp_obj = IgnoreField2("test", 0)
        exp_str = """{"str":"test"}"""
        @test Serde.to_json(exp_obj) == exp_str

        exp_obj = IgnoreField2("test", 1)
        exp_str = """{"str":"test","num":1}"""
        @test Serde.to_json(exp_obj) == exp_str
    end
end
