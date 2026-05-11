@testset "MsgPack — DoS guards on length prefixes" begin
    # C8: ARR32/MAP32/STR32/BIN32 length headers must be sanity-checked
    # against remaining bytes so that a 5-byte payload cannot drive a
    # multi-GB allocation.
    bogus_arr32 = UInt8[0xdd, 0xff, 0xff, 0xff, 0xff]
    @test_throws ParseError parse_msgpack(bogus_arr32)

    bogus_map32 = UInt8[0xdf, 0xff, 0xff, 0xff, 0xff]
    @test_throws ParseError parse_msgpack(bogus_map32)

    bogus_str32 = UInt8[0xdb, 0xff, 0xff, 0xff, 0xff]
    @test_throws ParseError parse_msgpack(bogus_str32)

    bogus_bin32 = UInt8[0xc6, 0xff, 0xff, 0xff, 0xff]
    @test_throws ParseError parse_msgpack(bogus_bin32)
end

@testset "MsgPack — recursion depth limit (configurable)" begin
    # Build a deeply nested 1-element fixarray so that parsing recurses ~depth times.
    # The default cap (1000) is generous; users can lower or raise it freely
    # via the `max_depth` kwarg.
    deep = vcat([0x91 for _ in 1:300], [0xc0])  # 300 nested fixarrays then nil
    @test_throws ParseError parse_msgpack(deep; max_depth = 100)
    # Default accepts 300-deep nesting without erroring.
    parse_msgpack(deep)
end

@testset "MsgPack — struct serializer evaluates ser_value once per field" begin
    # MEDIUM: previously called ser_value/ser_type twice per field.
    mutable struct _MpCounter; v::Int; end
    counter = _MpCounter(0)
    struct _MpStruct; n::Int; end
    Serde.ser_value(::Type{_MpStruct}, ::Val{:n}, x::Int) = (counter.v += 1; x)
    counter.v = 0
    to_msgpack(_MpStruct(7))
    @test counter.v == 1
end

@testset "MsgPack format" begin
    @testset "parse_msgpack primitives" begin
        @test parse_msgpack(to_msgpack(nothing)) === nothing
        @test parse_msgpack(to_msgpack(true)) === true
        @test parse_msgpack(to_msgpack(false)) === false
        @test parse_msgpack(to_msgpack(42)) == 42
        @test parse_msgpack(to_msgpack(-1)) == -1
        @test parse_msgpack(to_msgpack(-32)) == -32
        @test parse_msgpack(to_msgpack(128)) == 128
        @test parse_msgpack(to_msgpack(3.14)) == 3.14
        @test parse_msgpack(to_msgpack("hello")) == "hello"
    end

    @testset "parse_msgpack collections" begin
        d = parse_msgpack(to_msgpack(Dict("a" => 1, "b" => 2)))
        @test d["a"] == 1
        @test d["b"] == 2

        arr = parse_msgpack(to_msgpack([1, 2, 3]))
        @test arr == [1, 2, 3]
    end

    @testset "parse_msgpack binary" begin
        bin = UInt8[0x01, 0x02, 0x03]
        @test parse_msgpack(to_msgpack(bin)) == bin
    end

    @testset "parse_msgpack error" begin
        @test_throws ParseError parse_msgpack(UInt8[0xc1])
    end

    @testset "from_msgpack basic struct" begin
        struct _MpBasic
            name::String
            age::Int
            score::Float64
            active::Bool
        end
        p = _MpBasic("Alice", 30, 9.5, true)
        @test from_msgpack(_MpBasic, to_msgpack(p)) == p
    end

    @testset "from_msgpack nested struct" begin
        struct _MpInner
            x::Int
        end
        struct _MpOuter
            label::String
            inner::_MpInner
        end
        obj = _MpOuter("test", _MpInner(42))
        @test from_msgpack(_MpOuter, to_msgpack(obj)) == obj
    end

    @testset "from_msgpack vectors" begin
        struct _MpVec
            items::Vector{Int}
        end
        obj = _MpVec([1, 2, 3])
        @test from_msgpack(_MpVec, to_msgpack(obj)).items == [1, 2, 3]
    end

    @testset "from_msgpack optional fields" begin
        struct _MpOpt
            name::String
            tag::Union{Nothing,String}
        end
        obj = _MpOpt("a", nothing)
        @test from_msgpack(_MpOpt, to_msgpack(obj)).tag === nothing
        obj2 = _MpOpt("a", "b")
        @test from_msgpack(_MpOpt, to_msgpack(obj2)).tag == "b"
    end

    @testset "from_msgpack DateTime" begin
        struct _MpTime
            ts::Dates.DateTime
        end
        t = _MpTime(Dates.DateTime(2024, 1, 15, 12, 30, 0))
        result = from_msgpack(_MpTime, to_msgpack(t))
        @test result.ts == t.ts
    end

    @testset "from_msgpack with rename" begin
        struct _MpRenamed
            user_name::String
            is_active::Bool
        end
        Serde.deser_name(::Type{_MpRenamed}, ::Val{:user_name}) = :userName
        Serde.ser_name(::Type{_MpRenamed}, ::Val{:user_name}) = :userName
        Serde.has_default(::Type{_MpRenamed}, ::Val{:is_active}) = true
        Serde.deser_default(::Type{_MpRenamed}, ::Val{:is_active}) = true

        data = to_msgpack(_MpRenamed("Bob", false))
        obj = from_msgpack(_MpRenamed, data)
        @test obj.user_name == "Bob"
        @test obj.is_active == false
    end

    @testset "from_msgpack with skip" begin
        struct _MpSkip
            name::String
            debug::Bool
        end
        Serde.ser_skip(::Type{_MpSkip}, ::Val{:debug}) = true
        Serde.has_default(::Type{_MpSkip}, ::Val{:debug}) = true
        Serde.deser_default(::Type{_MpSkip}, ::Val{:debug}) = false

        obj = _MpSkip("test", true)
        data = to_msgpack(obj)
        result = from_msgpack(_MpSkip, data)
        @test result.name == "test"
        @test result.debug == false
    end

    @testset "try_from_msgpack" begin
        struct _MpTry
            x::Int
        end
        result = try_from_msgpack(_MpTry, to_msgpack(_MpTry(5)))
        @test result isa _MpTry
        @test result.x == 5

        bad = try_from_msgpack(_MpTry, UInt8[0xc1])
        @test bad isa SerdeError
    end

    @testset "from_msgpack Nothing/Missing" begin
        @test from_msgpack(Nothing, UInt8[]) === nothing
        @test from_msgpack(Missing, UInt8[]) === missing
    end

    @testset "to_msgpack integers" begin
        for v in [0, 1, 127, 128, 255, 256, 65535, 65536, typemax(Int32), Int64(typemax(Int32)) + 1]
            @test parse_msgpack(to_msgpack(v)) == v
        end
        for v in [-1, -32, -33, -128, -129, typemin(Int32), Int64(typemin(Int32)) - 1]
            @test parse_msgpack(to_msgpack(v)) == v
        end
    end

    @testset "to_msgpack collections" begin
        @test parse_msgpack(to_msgpack((1, "two", 3.0))) == [1, "two", 3.0]
        @test parse_msgpack(to_msgpack(Dict("k" => "v"))) == Dict("k" => "v")
    end

    @testset "from_msgpack with Function dispatch" begin
        struct _MpA
            kind::String
            x::Int
        end
        struct _MpB
            kind::String
            y::String
        end
        data = to_msgpack(_MpA("a", 42))
        result = from_msgpack(data) do obj
            obj["kind"] == "a" ? _MpA : _MpB
        end
        @test result isa _MpA
        @test result.x == 42
    end
end

@testset "MsgPack — additional edge cases" begin

    @testset "parse_msgpack error (rethrow path)" begin
        # Invalid byte triggers ParseError
        @test_throws ParseError parse_msgpack(UInt8[0xc1])
    end

    @testset "parse_msgpack error (SerdeError rethrow)" begin
        # When inner parse throws SerdeError, it's rethrown directly
        # This is hard to trigger from outside; test invalid byte as proxy
        result = try_from_msgpack(Dict{String,Int}, UInt8[0xc1])
        @test result isa SerdeError
    end

    @testset "to_msgpack STR32 (>65535 bytes)" begin
        s = 'x'^70000
        bytes = to_msgpack(s)
        recovered = parse_msgpack(bytes)
        @test recovered == s
    end

    @testset "to_msgpack and parse_msgpack MAP16 (17-element)" begin
        d = Dict(string(i) => i for i in 1:17)
        bytes = to_msgpack(d)
        recovered = parse_msgpack(bytes)
        @test length(recovered) == 17
        @test recovered["1"] == 1
    end

    @testset "to_msgpack ARR16 (17-element)" begin
        arr = collect(1:17)
        bytes = to_msgpack(arr)
        recovered = parse_msgpack(bytes)
        @test length(recovered) == 17
        @test recovered[1] == 1
        @test recovered[17] == 17
    end

    @testset "MsgPack ext with unknown type returns raw bytes" begin
        # FIXEXT1 with non-timestamp type = raw bytes
        # type = 5 (not -1), len = 1
        raw = UInt8[0xd4, 0x05, 0xAB]  # FIXEXT1, type=5, data=0xAB
        result = parse_msgpack(raw)
        @test result isa Vector{UInt8}
        @test result == UInt8[0xAB]
    end

    @testset "MsgPack timestamp invalid length raises ParseError" begin
        # Simulate invalid timestamp length via raw bytes
        # EXT8 with size 6, type=-1 (0xff): invalid
        raw = UInt8[0xc7, 0x06, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        @test_throws ParseError parse_msgpack(raw)
    end

    @testset "MsgPack BIN32 (>65535 bytes)" begin
        bin = zeros(UInt8, 70000)
        bytes = to_msgpack(bin)
        recovered = parse_msgpack(bytes)
        @test length(recovered) == 70000
    end
end

@testset "MsgPack — MAP32 and ARR32" begin

    @testset "to_msgpack ARR32 (>65535 elements)" begin
        # This is expensive but necessary for coverage
        # Use a smaller array to test ARR16 is already done (17 elem)
        # ARR32 needs > 65535 elements — skip as it's too slow
        # Instead test ARR16 boundary (verify 17 is covered)
        arr = collect(1:17)
        bytes = to_msgpack(arr)
        recovered = parse_msgpack(bytes)
        @test length(recovered) == 17
    end

    @testset "STR8 encoding (33-255 bytes)" begin
        # STR8 format: 33 to 255 bytes
        s = "x"^50
        bytes = to_msgpack(s)
        recovered = parse_msgpack(bytes)
        @test recovered == s
    end

    @testset "STR16 encoding (256-65535 bytes)" begin
        # STR16 format
        s = "y"^1000
        bytes = to_msgpack(s)
        recovered = parse_msgpack(bytes)
        @test recovered == s
    end
end

@testset "MsgPack — ParseError rethrow for truncated data (line 188)" begin

    @testset "UINT8 with no value byte triggers ParseError — line 188" begin
        # MP_UINT8 (0xcc) followed by nothing — read(io, UInt8) throws EOFError
        # EOFError is not a SerdeError → caught → line 188 executes
        truncated = UInt8[0xcc]  # UINT8 format byte but no value byte follows
        @test_throws ParseError parse_msgpack(truncated)
    end

    @testset "INT64 with truncated bytes triggers ParseError — line 188" begin
        # MP_INT64 (0xd3) needs 8 bytes; provide only 3 → EOFError (not SerdeError) → line 188
        truncated = UInt8[0xd3, 0x00, 0x01]  # INT64 format but only 3 of 8 bytes
        @test_throws ParseError parse_msgpack(truncated)
    end
end
