@testset "TOML format" begin
    @testset "parse_toml" begin
        d = parse_toml("key = \"value\"\nnum = 42")
        @test d["key"] == "value"
        @test d["num"] == 42

        @test_throws ParseError parse_toml("invalid = = toml")
    end

    @testset "from_toml basic" begin
        struct _TomlBasic
            name::String
            port::Int
        end
        obj = from_toml(_TomlBasic, "name = \"localhost\"\nport = 8080")
        @test obj.name == "localhost"
        @test obj.port == 8080
    end

    @testset "from_toml nested" begin
        struct _TomlPoint
            x::Int
            y::Int
        end
        struct _TomlPlot
            tag::String
            points::Vector{_TomlPoint}
        end
        toml = """
        tag = "line"
        [[points]]
        x = 1
        y = 0
        [[points]]
        x = 2
        y = 3
        """
        obj = from_toml(_TomlPlot, toml)
        @test obj.tag == "line"
        @test length(obj.points) == 2
        @test obj.points[1].x == 1
        @test obj.points[2].y == 3
    end

    @testset "to_toml basic" begin
        struct _TomlSer
            name::String
            value::Int
        end
        toml = to_toml(_TomlSer("test", 42))
        @test contains(toml, "name = \"test\"")
        @test contains(toml, "value = 42")
    end

    @testset "to_toml vector" begin
        struct _TomlVec
            items::Vector{Int}
        end
        toml = to_toml(_TomlVec([1, 2, 3]))
        @test contains(toml, "items = [1,2,3]")
    end

    @testset "Round-trip" begin
        struct _TomlRound
            host::String
            port::Int
        end
        original = _TomlRound("localhost", 3000)
        recovered = from_toml(_TomlRound, to_toml(original))
        @test recovered.host == original.host
        @test recovered.port == original.port
    end

    @testset "try_from_toml" begin
        struct _TomlTry; x::Int; end
        result = try_from_toml(_TomlTry, "invalid = = toml")
        @test result isa ParseError
    end
end

@testset "TOML — AbstractFloat serialization" begin

    @testset "to_toml AbstractFloat (non-nan)" begin
        struct _TomlFloat
            val::Float64
        end
        toml = to_toml(_TomlFloat(3.14))
        @test occursin("3.14", toml) || occursin("3.1", toml)
    end

    @testset "to_toml Float32 value" begin
        struct _TomlF32
            val::Float32
        end
        toml = to_toml(_TomlF32(Float32(1.5)))
        @test occursin("1.5", toml)
    end

    @testset "to_toml nested struct (indent path)" begin
        struct _TomlNestA
            value::Int
        end
        struct _TomlNestB
            name::String
            sub::_TomlNestA
        end
        toml = to_toml(_TomlNestB("test", _TomlNestA(42)))
        @test occursin("[sub]", toml)
        @test occursin("  value", toml)  # indented
    end

    @testset "to_toml with Dict integer negative key" begin
        toml = to_toml(Dict(-5 => "val"))
        @test occursin("-5", toml)
    end
end
