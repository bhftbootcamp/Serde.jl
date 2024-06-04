using Serde, Test

module TestGuessThis
    import Serde

    @eval function Serde.to_string(::Val{Serde.to_symbol(@__MODULE__)}, args...; kwargs...)
        "success"
    end
    module OrThis
        import Serde

        @eval function Serde.to_string(::Val{Serde.to_symbol(@__MODULE__)}, args...; kwargs...)
            "success2"
        end
    end
end

@testset verbose = true "Extensions" begin
    @testset "Case №1: Module not present" begin
        testval = Dict("a" => 1)

        @test_throws "import the 'JSON' module" Serde.to_json(testval)
        @test_throws "import the 'YAML' module" Serde.to_yaml(testval)
        @test_throws "import the 'EzXML' module" Serde.to_xml(testval)
        @test_throws "import the 'TOML' module" Serde.to_toml(testval)
        @test_throws "import the 'CSV' module" Serde.to_csv(testval)
    end

    @testset "Case №2: Module undefined" begin
        testval = Dict("a" => 1)

        @test_throws UndefVarError Serde.to_string(JSON, testval)
        @test_throws UndefVarError Serde.to_string(Blarg, testval)
    end

    @testset "Case №3: Module imported" begin
        import YAML
        testval = Dict("a" => 1)

        @test Serde.to_yaml(testval) == "a: 1\n"
        @test Serde.to_yaml(testval) == Serde.to_string(YAML, testval)
        @test_throws "import the 'JSON' module" Serde.to_json(testval)
    end

    @testset "Case №4: Custom module" begin
        @test Serde.to_string(TestGuessThis, Dict("a" => 1)) == "success"
    end

    @testset "Case №5: Custom nested module" begin
        @test Serde.to_string(TestGuessThis.OrThis, Dict("a" => 1)) == "success2"
    end

    struct TestMe
        a::UInt32
        b::Symbol
    end
    dict_val = Dict("a" => 1, "b" => :c)

    @testset "Case №6: YAML API equality" begin
        import YAML
        str_val = Serde.to_string(YAML, dict_val)::String

        @test Serde.to_string(YAML, dict_val) == Serde.YAML.to_yaml(dict_val)
        @test Serde.from_string(YAML, TestMe, str_val) == Serde.YAML.deser_yaml(TestMe, str_val)
        @test Serde.parse(YAML, str_val) == Serde.YAML.parse_yaml(str_val)
    end

    @testset "Case №7: JSON API equality" begin
        import JSON
        str_val = Serde.to_string(JSON, dict_val)::String

        @test Serde.to_string(JSON, dict_val) == Serde.JSON.to_json(dict_val)
        @test Serde.from_string(JSON, TestMe, str_val) == Serde.JSON.deser_json(TestMe, str_val)
        @test Serde.parse(JSON, str_val) == Serde.JSON.parse_json(str_val)
    end

    @testset "Case №8: XML API equality" begin
        import EzXML
        str_val = Serde.to_string(EzXML, dict_val)::String

        @test Serde.to_string(EzXML, dict_val) == Serde.XML.to_xml(dict_val)
        @test Serde.from_string(EzXML, TestMe, str_val) == Serde.XML.deser_xml(TestMe, str_val)
        @test Serde.parse(EzXML, str_val) == Serde.XML.parse_xml(str_val)
    end

    @testset "Case №9: CSV API equality" begin
        import CSV
        str_val = Serde.to_string(CSV, [dict_val, dict_val])::String

        @test Serde.to_string(CSV, [dict_val]) == Serde.CSV.to_csv([dict_val])
        @test Serde.from_string(CSV, TestMe, str_val) == Serde.CSV.deser_csv(TestMe, str_val)
        @test Serde.parse(CSV, str_val) == Serde.CSV.parse_csv(str_val)
    end

    @testset "Case №10: TOML API equality" begin
        import TOML
        str_val = Serde.to_string(TOML, dict_val)::String

        @test Serde.to_string(TOML, dict_val) == Serde.TOML.to_toml(dict_val)
        @test Serde.from_string(TOML, TestMe, str_val) == Serde.TOML.deser_toml(TestMe, str_val)
        @test Serde.parse(TOML, str_val) == Serde.TOML.parse_toml(str_val)
    end

    @testset "Case №11: Query API equality" begin
        import Serde.Query
        str_val = Serde.to_string(Query, dict_val)::String

        @test Serde.to_string(Query, dict_val) == Serde.Query.to_query(dict_val)
        @test Serde.from_string(Query, TestMe, str_val) == Serde.Query.deser_query(TestMe, str_val)
        @test Serde.parse(Query, str_val) == Serde.Query.parse_query(str_val)
    end
end
