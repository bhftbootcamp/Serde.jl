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
end
