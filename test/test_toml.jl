@testset "TOML — quoted-key escape is TOML-conformant" begin
    # Regression: `_toml_key` used `Base.escape_string`, which (a) does not
    # escape `"` and (b) emits non-conformant `\xNN` for control bytes.
    out = to_toml(Dict("a\"b" => 1, "\x01foo" => 2))
    @test occursin("\"a\\\"b\"", out)        # quote is escaped
    @test occursin("\"\\u0001foo\"", out)    # control byte uses \uXXXX
    @test !occursin("\\x", out)               # never emits \xNN
    # And the output must round-trip through the TOML parser.
    parsed = parse_toml(out)
    @test parsed["a\"b"] == 1
    @test parsed["\x01foo"] == 2
end

@testset "TOML — Inf encoding" begin
    # H9
    struct _TomlInf; x::Float64; y::Float64; z::Float64; end
    out = to_toml(_TomlInf(Inf, -Inf, NaN))
    @test occursin("inf", out)
    @test occursin("-inf", out)
    @test occursin("nan", out)
    # And the result must parse back
    parse_toml(out)
end

@testset "TOML — local datetime (no Z suffix)" begin
    # H11: Julia's DateTime is naive, must emit as TOML local-datetime.
    using Dates
    struct _TomlDT; t::DateTime; end
    out = to_toml(_TomlDT(DateTime(2024, 1, 2, 3, 4, 5, 6)))
    @test !occursin("Z", out)
    parsed = parse_toml(out)
    @test parsed["t"] == DateTime(2024, 1, 2, 3, 4, 5, 6)
end

@testset "TOML — Char field is emitted as inline string" begin
    # MEDIUM
    struct _TomlChar; c::Char; end
    out = to_toml(_TomlChar('x'))
    @test occursin("c = \"x\"", out)
end

@testset "TOML — heterogeneous array dispatch via all-simple check" begin
    # MEDIUM: previously dispatched on val[1] only.
    out = to_toml(Dict("xs" => [1, "two", 3.0]))
    parsed = parse_toml(out)
    @test parsed["xs"] == [1, "two", 3.0]
end

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
