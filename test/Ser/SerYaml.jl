# Ser/SerYaml

@testset verbose = true "SerYaml" begin
    @testset "Case №1: Dict to YAML" begin
        exp_obj = Dict(
            "v" => String["a", "b", "c"],
            "d" => Dict("s" => "foo", "i" => 163, "f" => 1.63),
            "b" => true,
            "s" => "foobar",
        )
        exp_str = """
        v:
          - "a"
          - "b"
          - "c"
        b: true
        s: "foobar"
        d:
          f: 1.63
          s: "foo"
          i: 163
        """
        @test Serde.to_yaml(exp_obj) == exp_str
    end

    @testset "Case №2: Struct to Yaml" begin
        struct YamlFoo2
            bool::Bool
            number::Float64
            nan::Float64
            inf::Float64
            _missing::Missing
            _nothing::Nothing
        end

        exp_obj = YamlFoo2(true, 163.163, NaN, Inf, missing, nothing)
        exp_str = """
        bool: true
        number: 163.163
        nan: .nan
        inf: .inf
        _missing: null
        _nothing: null
        """
        @test Serde.to_yaml(exp_obj) == exp_str
    end

    @testset "Case №3: Custom value" begin
        struct YamlFoo3
            name::String
            date::Date
            bytes::Vector{UInt8}
        end

        Serde.SerYaml.ser_value(h::YamlFoo3, ::Val{:bytes})::String =
            String(view(h.bytes, 1:length(h.bytes)))

        fields1(::Type{YamlFoo3}) = (:name,)

        exp_obj = YamlFoo3("test", Date("2022-01-01"), UInt8['t', 'e', 's', 't'])
        exp_str = "name: \"test\"\n"
        @test Serde.to_yaml(fields1, exp_obj) == exp_str

        exp_obj = YamlFoo3("test", Date("2022-01-01"), UInt8['t', 'e', 's', 't'])
        exp_str = "name: \"test\"\ndate: \"2022-01-01\"\nbytes:\n  - 116\n  - 101\n  - 115\n  - 116\n"
        @test Serde.to_yaml(fields1, exp_obj) == exp_str
    end

    @testset "Case №4: Ignore field" begin
        struct YamlFoo4_1
            str::String
            num::Int64
        end

        Serde.SerYaml.ser_ignore_field(::Type{YamlFoo4_1}, ::Val{:str}) = true

        exp_obj = YamlFoo4_1("test", 10)
        exp_str = "num: 10\n"
        @test Serde.to_yaml(exp_obj) == exp_str

        struct YamlFoo4_2
            str::String
            num::Int64
        end

        Serde.SerYaml.ser_ignore_field(::Type{YamlFoo4_2}, ::Val{:num}, v) = v == 0

        exp_obj = YamlFoo4_2("test", 0)
        exp_str = "str: \"test\"\n"
        @test Serde.to_yaml(exp_obj) == exp_str

        exp_obj = YamlFoo4_2("test", 1)
        exp_str = "str: \"test\"\nnum: 1\n"
        @test Serde.to_yaml(exp_obj) == exp_str
    end

    @testset "Case №5: All basic types" begin
        struct YamlFoo5
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

        exp_obj = YamlFoo5("str", 42, 24.6, true, missing, nothing, :symb, Float64, 'e')
        exp_str = """
        string: "str"
        int: 42
        float: 24.6
        bool: true
        miss: null
        noth: null
        symbol: "symb"
        type: Float64
        char: 'e'
        """
        @test Serde.to_yaml(exp_obj) == exp_str
    end

    @testset "Case №6: All hard types" begin
        @enum Num begin
            num1
            num2
        end

        struct YamlFoo6
            vector::Vector{Any}
            dict::Dict{Any,Any}
            tuple::Tuple
            ntuple::NamedTuple
            pair::Pair
            timetype::TimeType
            enm::Num
            set::Set
        end

        exp_obj = YamlFoo6(
            [1, "one", 6.3],
            Dict{Any,Any}(:a => 1, "b" => 6.3),
            (4, :b, '6'),
            (a = 1, b = 2),
            Pair(:e, 5),
            Date("2022-01-01"),
            num1,
            Set([1, 2]),
        )
        exp_str = """
        vector:
          - 1
          - "one"
          - 6.3
        dict:
          a: 1
          b: 6.3
        tuple:
          - 4
          - "b"
          - '6'
        ntuple:
          a: 1
          b: 2
        pair:
          e: 5
        timetype: "2022-01-01"
        enm: num1
        set:
          - 2
          - 1
        """
        @test Serde.to_yaml(exp_obj) == exp_str
    end

    @testset "Case №7: Ignore null" begin
        abstract type AbstractQuery_7 end

        struct YamlFoo7_1 <: AbstractQuery_7
            x::String
            b::Union{String,Nothing}
        end

        struct YamlFoo7_2 <: AbstractQuery_7
            x::Union{String,Nothing}
            b::Union{String,Nothing}
            c::Union{Int64,Nothing}
        end

        (Serde.SerYaml.ser_ignore_null(::Type{A})::Bool) where {A<:AbstractQuery_7} = true

        exp_obj = YamlFoo7_1("test", nothing, nothing)
        exp_str = "x: \"test\"\n"
        @test Serde.to_yaml(exp_obj) == exp_str

        exp_obj = YamlFoo7_2("test", nothing, 100)
        exp_str = "x: \"test\"\nc: 100\n"
        @test Serde.to_yaml(exp_obj) == exp_str

        exp_obj = YamlFoo7_2(nothing, nothing, 100)
        exp_str = "c: 100\n"
        @test Serde.to_yaml(exp_obj) == exp_str
    end

    @testset "Case №8: Сustom type" begin
        struct YamlFoo8
            dt::DateTime
        end

        Serde.SerYaml.ser_type(::Type{YamlFoo8}, x::DateTime) = string(datetime2unix(x))

        exp_obj = YamlFoo8(DateTime("2023-02-27T23:01:37.248"))
        exp_str = "dt: 1.677538897248e9"
        @test Serde.to_yaml(exp_obj) == exp_str
    end

    @testset "Case №9: Deep YAML" begin
        struct YamlFoo9_1
            bool::Bool
            empty::Nothing
        end

        struct YamlFoo9_2
            set::Set{String}
            pair::Pair
            datatype::DataType
            onemoreobject::YamlFoo9_1
        end

        struct YamlFoo9_3
            value::Int64
            text::String
            object::YamlFoo9_2
            array::Vector{Int64}
        end

        exp_obj = YamlFoo9_3(
            34,
            "sertupe",
            YamlFoo9_2(Set(["a", "b"]), :a => 2, YamlFoo9_3, YamlFoo9_1(true, nothing)),
            [1, 2, 3],
        )
        exp_str = """
        value: 34
        text: "sertupe"
        object:
          set:
            - "b"
            - "a"
          pair:
            a: 2
          datatype: YamlFoo9_3
          onemoreobject:
            bool: true
            empty: null
        array:
          - 1
          - 2
          - 3
        """
        @test Serde.to_yaml(exp_obj) == exp_str
    end

    @testset "Case №10: Linefeed in collections" begin
        struct YamlFoo10
            dict::Vector{AbstractDict}
            vector::Vector{AbstractVector}
            set::Vector{AbstractSet}
            tuple::Vector{Tuple}
            ntuple::Vector{NamedTuple}
            pair::Vector{Pair}
        end

        exp_obj = YamlFoo10(
            [Dict("dict1_1" => "foo"), Dict("dict2_1" => "bar", "dict2_2" => "baz")],
            [["vector", "of", "strings"], ["another", "one"]],
            [Set([1, 2]), Set([3]), Set([4, 5, 6])],
            [('a', 'b'), ('c', "c2"), ('d', 'e', 'f')],
            [(a = 1, b = 2)],
            [Pair("one", 1), Pair("two", 2)],
        )
        exp_str = """
        dict:
          - dict1_1: "foo"
          - dict2_1: "bar"
            dict2_2: "baz"
        vector:
          - - "vector"
            - "of"
            - "strings"
          - - "another"
            - "one"
        set:
          - - 2
            - 1
          - - 3
          - - 5
            - 4
            - 6
        tuple:
          - - 'a'
            - 'b'
          - - 'c'
            - "c2"
          - - 'd'
            - 'e'
            - 'f'
        ntuple:
          - a: 1
            b: 2
        pair:
          - one: 1
          - two: 2
        """
        @test Serde.to_yaml(exp_obj) == exp_str
    end
end
