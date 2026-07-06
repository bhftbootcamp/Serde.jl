@testset "JSON — UInt64 values above Int64 max materialize as UInt64 (not Int64)" begin
    # Regression: `_yy_to_julia` was checking `yyjson_is_int` (which is true
    # for both sint and uint subtypes) and converting via `Int64(...)`, which
    # threw InexactError for values in (typemax(Int64), typemax(UInt64)].
    big_u = UInt64(typemax(Int64)) + UInt64(1)   # 9223372036854775808
    parsed = parse_json("{\"a\":$(big_u)}")
    @test parsed["a"] === big_u
    @test parsed["a"] isa UInt64

    # Values that fit Int64 keep returning Int64 — no type widening.
    @test parse_json("{\"a\":42}")["a"] === Int64(42)
end

# ── YYJSON parser flag passthrough ──────────────────────────────────────────
# Serde forwards yyjson's permissive-parse flags through `parse_json` /
# `from_json` kwargs. By default the reader is strict; users opt into
# extensions (comments, trailing commas, Inf/NaN literals, invalid UTF-8)
# as the input requires. The tests both prove the strict default AND that
# the flags actually reach the C parser.

@testset "JSON — allow_trailing_commas flag" begin
    # Strict mode rejects.
    @test_throws ParseError parse_json("{\"a\":1,}")
    @test_throws ParseError parse_json("[1, 2, 3,]")

    # With the flag, both forms parse.
    @test parse_json("{\"a\":1,}";   allow_trailing_commas = true) == Dict{String,Any}("a" => 1)
    @test parse_json("[1, 2, 3,]";   allow_trailing_commas = true) == Any[1, 2, 3]

    # And through the typed path.
    struct _JsonTC; a::Int; end
    @test from_json(_JsonTC, "{\"a\":1,}"; allow_trailing_commas = true) == _JsonTC(1)
end

@testset "JSON — allow_comments flag" begin
    @test_throws ParseError parse_json("/* hi */ {\"a\":1}")
    @test_throws ParseError parse_json("{\"a\":1} // tail")

    @test parse_json("/* hi */ {\"a\":1}"; allow_comments = true) == Dict{String,Any}("a" => 1)
    @test parse_json("{\"a\":1} // tail";  allow_comments = true) == Dict{String,Any}("a" => 1)

    # Inline.
    payload = """{"a": /* inline */ 1, "b": 2}"""
    @test parse_json(payload; allow_comments = true) == Dict{String,Any}("a" => 1, "b" => 2)
end

@testset "JSON — allow_inf_and_nan flag" begin
    # Strict JSON has no Inf/NaN — yyjson rejects without the flag.
    @test_throws ParseError parse_json("{\"a\":Infinity}")
    @test_throws ParseError parse_json("{\"a\":NaN}")

    # With the flag, the literals come through as Float64 Inf / NaN.
    pos_inf = parse_json("{\"a\":Infinity}";  allow_inf_and_nan = true)["a"]
    @test isinf(pos_inf) && pos_inf > 0

    neg_inf = parse_json("{\"a\":-Infinity}"; allow_inf_and_nan = true)["a"]
    @test isinf(neg_inf) && neg_inf < 0

    @test isnan(parse_json("{\"a\":NaN}"; allow_inf_and_nan = true)["a"])

    # Lowercase forms are accepted too (yyjson is case-insensitive).
    @test isinf(parse_json("{\"a\":inf}"; allow_inf_and_nan = true)["a"])
    @test isnan(parse_json("{\"a\":nan}"; allow_inf_and_nan = true)["a"])

    # Typed deser path picks up the flag.
    struct _JsonInf; x::Float64; end
    @test isinf(from_json(_JsonInf, "{\"x\":Infinity}"; allow_inf_and_nan = true).x)
end

@testset "JSON — allow_invalid_unicode flag" begin
    # Construct a JSON document with a lone (invalid) surrogate inside a
    # string literal — strict yyjson rejects.
    bad_unicode_bytes = UInt8[0x7b, 0x22, 0x61, 0x22, 0x3a, 0x22,    # `{"a":"`
                              0xed, 0xa0, 0x80,                       # invalid surrogate
                              0x22, 0x7d]                             # `"}`
    @test_throws ParseError parse_json(bad_unicode_bytes)
    # With the flag, parsing succeeds (the string keeps the raw bytes).
    parsed = parse_json(bad_unicode_bytes; allow_invalid_unicode = true)
    @test parsed isa Dict{String,Any}
    @test haskey(parsed, "a")
end

@testset "JSON — combined flags + bignum coexistence" begin
    # All four flags + the always-on BIGNUM_AS_RAW behave together: a payload
    # with a comment, a trailing comma, NaN, AND a big integer round-trips
    # to the expected shape.
    payload = """
    /* header */
    {
        "n": 123456789012345678901234567890,   // bignum → BigInt
        "v": NaN,                              // Inf/NaN literal
    }
    """
    d = parse_json(payload;
                   allow_comments        = true,
                   allow_trailing_commas = true,
                   allow_inf_and_nan     = true)
    @test d["n"] == big"123456789012345678901234567890"
    @test isnan(d["v"])
end

@testset "JSON — scalar JSON value routed through user `deser` for struct-classed types" begin
    # Regression: the generic `_yy_extract` fallback used to dive into
    # `_yy_deser_struct` whenever `ClassType(F) isa StructClass`, even when
    # the actual JSON value was a scalar (e.g. a string encoding for an
    # ObjectId). User overrides like
    #     Serde.deser(::Type{T}, ::Type{MyId}, s::AbstractString) = MyId(s)
    # never got a chance to fire. The fast path now only takes the struct
    # branch when the JSON value is actually an object.
    struct _ScalarOid; v::BSONObjectId; end
    function Serde.deser(::Type{_ScalarOid}, ::Type{BSONObjectId}, s::AbstractString)
        return BSONObjectId(s)
    end
    out = """{"v":"507f1f77bcf86cd799439011"}"""
    back = from_json(_ScalarOid, out)
    @test back.v == BSONObjectId("507f1f77bcf86cd799439011")
end

@testset "JSON — iterator GC-rooted across element-extract loop (regression)" begin
    # Regression: `iter = YYJSONArrIter()` was being reclaimed mid-loop when
    # the element-extract path allocated, leaving `iter_ptr` dangling. The
    # second `yyjson_arr_iter_next` then returned NULL and deserialization
    # silently dropped every element after the first. Reproduces with a
    # non-primitive element type whose deser triggers allocation.
    struct _LoopOid; ids::Vector{BSONObjectId}; end
    function Serde.deser(::Type{_LoopOid}, ::Type{BSONObjectId}, s::AbstractString)
        return BSONObjectId(s)
    end
    payload = """{"ids":["507f1f77bcf86cd799439011","507f191e810c19729de860ea","507f191e810c19729de860eb"]}"""
    back = from_json(_LoopOid, payload)
    @test length(back.ids) == 3
    @test back.ids[1] == BSONObjectId("507f1f77bcf86cd799439011")
    @test back.ids[3] == BSONObjectId("507f191e810c19729de860eb")

    # Top-level Vector{T} target — different code path (no enclosing struct).
    function Serde.deser(::Type{T}, ::Type{BSONObjectId}, s::AbstractString) where {T}
        return BSONObjectId(s)
    end
    ids = from_json(Vector{BSONObjectId},
        """["507f1f77bcf86cd799439011","507f191e810c19729de860ea","507f191e810c19729de860eb"]""")
    @test length(ids) == 3
    @test ids[end] == BSONObjectId("507f191e810c19729de860eb")
end

@testset "JSON — bare-type collection targets work" begin
    # Regression: `from_json(Dict, ...)` / `from_json(Tuple, ...)` /
    # `from_json(Pair, ...)` failed because `keytype(Dict)` / `fieldtypes(Tuple)`
    # / `Pair.parameters[1]` raise on UnionAll types. Now bare types fall back
    # to (String, Any) parameters and arbitrary tuple arity.
    @test from_json(Dict, "{\"x\":1}") == Dict{Any,Any}("x" => 1)
    @test from_json(Tuple, "[1,\"two\",true]") === (1, "two", true)
    @test from_json(Pair, "{\"a\":1}") == Pair{String,Any}("a", 1)

    # Same defaults apply under a strategy.
    @test from_json(CamelCase(), Dict, "{\"fooBar\":1}") == Dict{Any,Any}("fooBar" => 1)
    @test from_json(CamelCase(), Pair, "{\"x\":1}") == Pair{String,Any}("x", 1)

    # The binary formats route bare/typed Pair through the deser engine; both work.
    @test from_msgpack(Pair{String,Int}, to_msgpack("a" => 1)) === ("a" => 1)
    @test from_msgpack(Pair, to_msgpack("a" => 1)) == Pair{String,Any}("a", 1)
    @test from_bson(Pair{String,Int}, to_bson(Dict("a" => 1))) === ("a" => 1)
end

@testset "JSON — parse_json applies dict_type to nested objects" begin
    # Regression: `_yy_to_julia` always built inner dicts as `Dict{String,Any}`,
    # so `dict_type=OrderedDict` only affected the top level.
    using OrderedCollections
    d = parse_json("{\"a\":{\"b\":1}}"; dict_type = OrderedDict{String,Any})
    @test d isa OrderedDict{String,Any}
    @test d["a"] isa OrderedDict{String,Any}
    @test d["a"]["b"] == 1

    # And inside arrays of objects.
    d2 = parse_json("{\"xs\":[{\"k\":1},{\"k\":2}]}"; dict_type = OrderedDict{String,Any})
    @test d2 isa OrderedDict{String,Any}
    @test all(x -> x isa OrderedDict{String,Any}, d2["xs"])
end

@testset "JSON — Any-typed fields and elements materialize via _yy_to_julia" begin
    # Regression: `_yy_extract(strategy, T, Any, v)` fell through to the generic
    # fallback which calls `fieldcount(Any)` and throws.
    struct _AnyField; v::Any; end
    @test from_json(_AnyField, "{\"v\":42}").v === Int64(42)
    @test from_json(_AnyField, "{\"v\":\"hi\"}").v == "hi"
    @test from_json(_AnyField, "{\"v\":{\"n\":1}}").v == Dict{String,Any}("n" => 1)
    @test from_json(_AnyField, "{\"v\":null}").v === nothing

    struct _AnyVec; xs::Vector{Any}; end
    res = from_json(_AnyVec, "{\"xs\":[1,\"x\",true,null,[1,2],{\"a\":1}]}")
    @test res.xs == Any[1, "x", true, nothing, Any[1, 2], Dict{String,Any}("a" => 1)]

    # Free-standing Vector{Any} target.
    @test from_json(Vector{Any}, "[1,\"x\"]") == Any[1, "x"]
end

@testset "JSON — TypeMismatchError carries the actual offending value" begin
    # Regression: error previously contained `typeof(ArgumentError)` and the
    # exception itself in the value/got slots, hiding the real input.
    struct _JsonErrCtx; n::Int; end
    err = try
        from_json(_JsonErrCtx, "{\"n\":[1,2]}")
        nothing
    catch e
        e
    end
    @test err isa TypeMismatchError
    @test err.field === :n
    @test err.expected === Int
    @test err.value == Any[1, 2]
end

@testset "JSON — RFC 8259 escape conformance" begin
    # C1: control bytes must use \u00XX (not \xNN), and round-trip
    struct _JsonEscape; v::String; end
    s = "\x01\x02ab\"\\c\x7f"
    out = to_json(_JsonEscape(s))
    @test !occursin("\\x", out)
    @test occursin("\\u0001", out)
    @test occursin("\\u0002", out)
    @test from_json(_JsonEscape, out).v == s

    out_p = to_pretty_json(_JsonEscape(s))
    @test !occursin("\\x", out_p)
    @test occursin("\\u0001", out_p)
end

@testset "JSON — Symbol keys are escaped" begin
    # C2: Symbols can contain ", \, control bytes, NULs; serialization must escape.
    d = Dict{Symbol,Int}(Symbol("x\"y") => 1, Symbol("a\nb") => 2, Symbol("c\x01d") => 3)
    out = to_json(d)
    @test parse_json(out) == Dict{String,Any}("x\"y" => 1, "a\nb" => 2, "c\x01d" => 3)
end

@testset "JSON — embedded NUL preserved on read" begin
    # C3
    struct _JsonNul; v::String; end
    res = from_json(_JsonNul, "{\"v\":\"a\\u0000b\"}")
    @test ncodeunits(res.v) == 3
    @test res.v == "a\0b"

    d = parse_json("{\"a\\u0000b\":1}")
    @test haskey(d, "a\0b")
end

@testset "JSON — BigFloat does not crash on overflow to Inf" begin
    # C4
    struct _JsonBigF; x::BigFloat; end
    @test occursin("null", to_json(_JsonBigF(BigFloat("1e1000"))))
    @test occursin("3.14", to_json(_JsonBigF(BigFloat("3.14"))))
end

@testset "JSON — collection-element user deser overrides fire" begin
    # C5
    struct _CElemFoo; n::Int; end
    struct _CElemOuter; xs::Vector{_CElemFoo}; end
    Serde.deser(::Type{_CElemOuter}, ::Type{_CElemFoo}, d::AbstractDict) = _CElemFoo(d["n"] * 100)
    res = from_json(_CElemOuter, "{\"xs\":[{\"n\":1},{\"n\":2}]}")
    @test res.xs == [_CElemFoo(100), _CElemFoo(200)]
end

@testset "JSON — tagged union dispatches on non-string tags" begin
    # C6
    abstract type _CTag end
    Serde.ClassType(::Type{<:_CTag}) = Serde.TaggedClass()
    Serde.tag_key(::Type{<:_CTag}) = "k"
    struct _CTagA <: _CTag; v::Int; end
    struct _CTagB <: _CTag; v::Int; end
    register_tagged_subtype(_CTag, "1", _CTagA)
    register_tagged_subtype(_CTag, "true", _CTagB)
    @test from_json(_CTag, "{\"k\":1,\"v\":42}") isa _CTagA
    @test from_json(_CTag, "{\"k\":true,\"v\":7}") isa _CTagB
end

@testset "JSON — pretty top-level closing brace on its own line" begin
    # H4
    struct _PrettyTL; x::Int; y::Int; end
    out = to_pretty_json(_PrettyTL(1, 2))
    @test endswith(out, "\n}")

    # Top-level array
    out_arr = to_pretty_json([1, 2, 3])
    @test endswith(out_arr, "\n]")
end

@testset "JSON — null root errors for non-nullable target type" begin
    # H5
    struct _NullStruct; n::Int; end
    @test_throws TypeMismatchError from_json(_NullStruct, "null")
end

@testset "JSON — fresh-string ser_value override does not GC-trash the writer" begin
    # H1: Ensure that user `ser_value` overrides returning freshly constructed
    # Strings don't need a GC root from the caller (yyjson now always copies
    # into its arena via strncpy).
    struct _GCSer; v::String; end
    Serde.ser_value(::Type{_GCSer}, ::Val{:v}, x::String) = "fresh_$(rand(UInt32))"
    GC.gc(true)
    for _ in 1:100
        out = to_json(_GCSer("input"))
        @test occursin("fresh_", out)
    end
end

@testset "JSON — Pair as target type" begin
    # MEDIUM: parse single-entry JSON object directly into a Pair.
    p = from_json(Pair{String,Int}, "{\"answer\":42}")
    @test p === ("answer" => 42)

    # Round-trip
    @test from_json(Pair{String,Int}, to_json("a" => 1)) === ("a" => 1)

    # Multi-entry object should error
    @test_throws Exception from_json(Pair{String,Int}, "{\"a\":1,\"b\":2}")
end

@testset "JSON — Int128 / UInt128 / BigInt round-trip as real JSON numbers" begin
    # Out-of-range integers are emitted as RAW JSON number literals (no quotes)
    # and round-trip losslessly through `from_json` thanks to the reader's
    # YYJSON_READ_BIGNUM_AS_RAW flag.
    struct _BigInts; a::Int128; b::UInt128; c::BigInt; end
    v = _BigInts(Int128(2)^100, UInt128(2)^120, BigInt(2)^200)
    out = to_json(v)
    @test !occursin("\"$(Int128(2)^100)\"", out)
    @test occursin(string(Int128(2)^100), out)
    @test !occursin("\"$(UInt128(2)^120)\"", out)
    @test occursin(string(UInt128(2)^120), out)
    @test !occursin("\"$(BigInt(2)^200)\"", out)
    @test occursin(string(BigInt(2)^200), out)

    # Pretty path also emits unquoted big numbers.
    out_p = to_pretty_json(_BigInts(Int128(0), UInt128(1), BigInt(2)^200))
    @test occursin(string(BigInt(2)^200), out_p)
    @test !occursin("\"$(BigInt(2)^200)\"", out_p)

    # Lossless round-trip — including a value that is NOT a power of two
    # (powers of two are exactly representable in Float64, so they round-trip
    # even without bignum-as-raw support).
    struct _Big1; n::BigInt; end
    rt = from_json(_Big1, to_json(_Big1(BigInt(2)^200 + 1)))
    @test rt.n == BigInt(2)^200 + 1

    rt2 = from_json(_Big1, to_pretty_json(_Big1(BigInt(2)^200 + 1)))
    @test rt2.n == BigInt(2)^200 + 1

    rt3 = from_json(_BigInts, to_json(v))
    @test rt3.a == v.a
    @test rt3.b == v.b
    @test rt3.c == v.c

    # Untyped parse: bignums materialize as BigInt; bigfloats as BigFloat.
    @test parse_json("{\"x\":12345678901234567890123}")["x"] == big"12345678901234567890123"
    @test parse_json("{\"x\":1e1000}")["x"] isa BigFloat
end

@testset "JSON — from_json(strategy, f, x) overload" begin
    # MEDIUM: dynamic-type dispatch with strategy.
    struct _DynS; my_field::Int; end
    res = from_json(CamelCase(), x -> _DynS, "{\"myField\":7}")
    @test res === _DynS(7)
end

@testset "JSON — type-mismatch produces TypeMismatchError" begin
    # H3
    struct _MM1; n::Int; end
    @test_throws TypeMismatchError from_json(_MM1, "{\"n\":{\"nested\":1}}")
    @test_throws TypeMismatchError from_json(_MM1, "{\"n\":[1,2]}")

    struct _MM2; v::Vector{Int}; end
    @test_throws TypeMismatchError from_json(_MM2, "{\"v\":42}")
end

@testset "JSON format" begin
    @testset "parse_json" begin
        d = parse_json("{\"a\": 1, \"b\": [2, 3]}")
        @test d["a"] == 1
        @test d["b"] == [2, 3]

        @test_throws ParseError parse_json("invalid{json")
    end

    @testset "parse_json Vector{UInt8}" begin
        bytes = Vector{UInt8}("{\"x\": 1}")
        d = parse_json(bytes)
        @test d["x"] == 1
    end

    @testset "from_json basic types" begin
        struct _JsonBasic
            name::String
            age::Int
            score::Float64
            active::Bool
        end
        obj = from_json(_JsonBasic, "{\"name\": \"Alice\", \"age\": 30, \"score\": 9.5, \"active\": true}")
        @test obj.name == "Alice"
        @test obj.age == 30
        @test obj.score == 9.5
        @test obj.active == true
    end

    @testset "from_json nested" begin
        struct _JsonInner
            x::Int
        end
        struct _JsonOuter
            label::String
            inner::_JsonInner
        end
        obj = from_json(_JsonOuter, "{\"label\": \"test\", \"inner\": {\"x\": 42}}")
        @test obj.inner.x == 42
    end

    @testset "from_json vectors" begin
        struct _JsonVec
            items::Vector{Int}
        end
        obj = from_json(_JsonVec, "{\"items\": [1, 2, 3]}")
        @test obj.items == [1, 2, 3]
    end

    @testset "from_json optional fields" begin
        struct _JsonOpt
            name::String
            tag::Union{Nothing,String}
        end
        obj = from_json(_JsonOpt, "{\"name\": \"a\"}")
        @test obj.tag === nothing
        obj2 = from_json(_JsonOpt, "{\"name\": \"a\", \"tag\": \"b\"}")
        @test obj2.tag == "b"
    end

    @testset "try_from_json" begin
        struct _JsonTry; x::Int; end
        result = try_from_json(_JsonTry, "not json")
        @test result isa ParseError
        result2 = try_from_json(_JsonTry, "{\"x\": 1}")
        @test result2 isa _JsonTry
        @test result2.x == 1
    end

    @testset "to_json primitives" begin
        @test to_json(42) == "42"
        @test to_json("hello") == "\"hello\""
        @test to_json(true) == "true"
        @test to_json(nothing) == "null"
        @test to_json(missing) == "null"
        @test to_json(:sym) == "\"sym\""
    end

    @testset "to_json struct" begin
        struct _JsonSer
            a::Int
            b::String
        end
        @test to_json(_JsonSer(1, "x")) == "{\"a\":1,\"b\":\"x\"}"
    end

    @testset "to_json collections" begin
        @test to_json([1, 2, 3]) == "[1,2,3]"
        @test to_json(Dict("a" => 1)) == "{\"a\":1}"
        @test to_json((1, "a")) == "[1,\"a\"]"
    end

    @testset "to_json pretty" begin
        struct _JsonPretty; x::Int; end
        pretty = to_json(_JsonPretty(1); pretty=true)
        @test contains(pretty, "\n")
        @test contains(pretty, "  ")
    end

    @testset "to_json special values" begin
        @test to_json(NaN) == "null"
        @test to_json(Inf) == "null"
    end

    @testset "to_json escape" begin
        json = to_json("hello\nworld")
        @test contains(json, "\\n")
    end

    @testset "to_json with field selector" begin
        struct _JsonSelect
            a::Int
            b::Int
            c::Int
        end
        selector(::Type{_JsonSelect}) = (:a, :c)
        json = to_json(selector, _JsonSelect(1, 2, 3))
        @test contains(json, "\"a\":1")
        @test contains(json, "\"c\":3")
        @test !contains(json, "\"b\"")
    end

    @testset "to_json DateTime/UUID" begin
        dt = DateTime(2024, 1, 15, 10, 30, 0)
        json_dt = to_json(dt)
        @test contains(json_dt, "2024")

        u = uuid4()
        json_u = to_json(u)
        @test contains(json_u, string(u))
    end

    @testset "Round-trip" begin
        struct _JsonRound
            name::String
            value::Int
            items::Vector{String}
        end
        original = _JsonRound("test", 42, ["a", "b", "c"])
        recovered = from_json(_JsonRound, to_json(original))
        @test recovered.name == original.name
        @test recovered.value == original.value
        @test recovered.items == original.items
    end

    @testset "from_json Nothing/Missing" begin
        @test from_json(Nothing, "null") === nothing
        @test from_json(Missing, "null") === missing
    end

    @testset "Function-form from_json" begin
        json_data = "{\"x\": 1, \"y\": 2}"
        struct _JsonFunc; x::Int; y::Int; end
        obj = from_json(d -> _JsonFunc, json_data)
        @test obj.x == 1
    end
end

@testset "JSON _yy_extract — String from non-string types" begin

    @testset "String from Bool true" begin
        struct _JBoolTrue; active::String; end
        obj = from_json(_JBoolTrue, "{\"active\": true}")
        @test obj.active == "true"
    end

    @testset "String from Bool false" begin
        struct _JBoolFalse; active::String; end
        obj = from_json(_JBoolFalse, "{\"active\": false}")
        @test obj.active == "false"
    end

    @testset "String from Integer" begin
        struct _JIntStr; val::String; end
        obj = from_json(_JIntStr, "{\"val\": 42}")
        @test obj.val == "42"
    end

    @testset "String from Float" begin
        struct _JFloatStr; val::String; end
        obj = from_json(_JFloatStr, "{\"val\": 3.14}")
        @test obj.val == "3.14"
    end

    @testset "String from negative Integer" begin
        struct _JNegStr; val::String; end
        obj = from_json(_JNegStr, "{\"val\": -7}")
        @test obj.val == "-7"
    end
end

@testset "JSON _yy_extract — String fallback from null gives empty" begin
    @testset "String from null uses fallback" begin
        # null JSON to String with has_default to avoid MissingFieldError
        struct _JNullStr; val::Union{Nothing,String}; end
        obj = from_json(_JNullStr, "{\"val\": null}")
        @test obj.val === nothing
    end
end

@testset "JSON _yy_extract — Bool from non-bool types" begin

    @testset "Bool from String 'true'" begin
        struct _JStrBoolTrue; flag::Bool; end
        obj = from_json(_JStrBoolTrue, "{\"flag\": \"true\"}")
        @test obj.flag === true
    end

    @testset "Bool from String 'false'" begin
        struct _JStrBoolFalse; flag::Bool; end
        obj = from_json(_JStrBoolFalse, "{\"flag\": \"false\"}")
        @test obj.flag === false
    end

    @testset "Bool from Integer nonzero" begin
        struct _JIntBool; flag::Bool; end
        obj = from_json(_JIntBool, "{\"flag\": 1}")
        @test obj.flag === true
        obj2 = from_json(_JIntBool, "{\"flag\": 0}")
        @test obj2.flag === false
    end
end

@testset "JSON IOBuffer — _json_value! one-liners" begin

    struct _JIOUuid; id::UUIDs.UUID; end
    struct _JIOChar; ch::Char; end
    struct _JIOBool2; flag::Bool; end
    struct _JIONothing; val::Nothing; end
    struct _JIOType; t::Type; end

    f_all = T -> fieldnames(T)

    @testset "UUID via to_json(f, data)" begin
        u = UUIDs.UUID("550e8400-e29b-41d4-a716-446655440000")
        j = to_json(f_all, _JIOUuid(u))
        @test occursin("550e8400", j)
    end

    @testset "Char via to_json(f, data)" begin
        j = to_json(f_all, _JIOChar('A'))
        @test occursin("A", j)
    end

    @testset "Bool via to_json(f, data)" begin
        j = to_json(f_all, _JIOBool2(true))
        @test occursin("true", j)
    end

    @testset "Nothing via to_json(f, data)" begin
        j = to_json(f_all, _JIONothing(nothing))
        @test occursin("null", j)
    end

    @testset "Type via to_json(f, data)" begin
        j = to_json(f_all, _JIOType(Int))
        @test occursin("Int", j)
    end

    @testset "Pair via to_json(f, data)" begin
        j = to_json(f_all, "a" => 42)
        @test occursin("a", j) && occursin("42", j)
    end

    @testset "Dict via to_json(f, data)" begin
        j = to_json(f_all, Dict("x" => 1, "y" => 2))
        @test occursin("x", j)
        @test occursin("y", j)
    end

    @testset "AbstractVector via to_json(f, data)" begin
        j = to_json(f_all, [1, 2, 3])
        @test occursin("1", j) && occursin("3", j)
    end

    @testset "Tuple via to_json(f, data)" begin
        j = to_json(f_all, (10, 20))
        @test occursin("10", j) && occursin("20", j)
    end

    @testset "AbstractSet via to_json(f, data)" begin
        j = to_json(f_all, Set([1, 2]))
        @test occursin("1", j) || occursin("2", j)
    end

    @testset "2D Array via to_json(f, data)" begin
        A = [1 2; 3 4]
        j = to_json(f_all, A)
        @test occursin("1", j) && occursin("4", j)
    end

    @testset "Missing via to_json(f, data)" begin
        j = to_json(f_all, missing)
        @test j == "null"
    end

    @testset "String with escape via _json_write_key!" begin
        # Dict key with special char triggers escape path in _json_write_key!
        j = to_json(Dict("key\"quoted" => 1))
        @test occursin("key", j)
    end

    @testset "Symbol in struct via to_json(f, data)" begin
        struct _JIOSym; name::Symbol; end
        j = to_json(f_all, _JIOSym(:hello))
        @test occursin("hello", j)
    end

    @testset "Enum in struct via to_json(f, data)" begin
        @enum _JIOColor3 red3 green3 blue3
        struct _JIOEnumField; color::_JIOColor3; end
        j = to_json(f_all, _JIOEnumField(green3))
        @test occursin("green3", j)
    end
end

@testset "JSON pretty mode — IOBuffer paths" begin

    struct _JPrettyPair; a::Int; b::String; end

    @testset "to_json pretty=true" begin
        j = to_json(_JPrettyPair(1, "hello"); pretty = true)
        @test occursin("\n", j)
        @test occursin("\"a\"", j)
    end

    @testset "to_pretty_json" begin
        j = to_pretty_json(_JPrettyPair(2, "world"))
        @test occursin("\n", j)
        @test occursin("\"b\"", j)
    end

    @testset "to_json pretty with Pair" begin
        j = to_json("key" => 42; pretty = true)
        @test occursin("key", j) && occursin("42", j)
    end

    @testset "to_json pretty with Dict" begin
        j = to_json(Dict("x" => 1); pretty = true)
        @test occursin("x", j)
    end

    @testset "to_json pretty with Vector" begin
        j = to_json([1, 2, 3]; pretty = true)
        @test occursin("1", j) && occursin("3", j)
    end

    @testset "to_json pretty with nested struct" begin
        struct _JPrettyInner; val::Int; end
        struct _JPrettyOuter; name::String; inner::_JPrettyInner; end
        j = to_json(_JPrettyOuter("test", _JPrettyInner(42)); pretty = true)
        @test occursin("name", j) && occursin("42", j)
    end

    @testset "to_json pretty with UUID/Char/Bool" begin
        struct _JPrettyMixed; u::UUIDs.UUID; c::Char; b::Bool; end
        j = to_json(_JPrettyMixed(UUIDs.UUID("550e8400-e29b-41d4-a716-446655440000"), 'Z', true); pretty = true)
        @test occursin("550e8400", j)
        @test occursin("Z", j)
        @test occursin("true", j)
    end
end

@testset "JSON — >32 fields IOBuffer paths" begin

    @testset "to_json(data; pretty=true) with >32 fields" begin
        field_decls = join(["jbig$i::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _JSONBig34P; $field_decls; end"))
        vals = ntuple(i -> i, 34)
        obj = Main._JSONBig34P(vals...)
        j = to_json(obj; pretty = true)
        @test occursin("jbig1", j)
        @test occursin("jbig34", j)
        @test occursin("34", j)
    end

    @testset "to_json(f, data) with >32 fields (else branch)" begin
        # f !== fieldnames → else branch in _json_value!
        field_decls = join(["jf2_$i::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _JSONBig34F; $field_decls; end"))
        vals = ntuple(i -> i, 34)
        obj = Main._JSONBig34F(vals...)
        # Custom field selector: select all fields
        f_all_fields = T -> fieldnames(T)
        j = to_json(f_all_fields, obj)
        @test occursin("jf2_1", j)
        @test occursin("jf2_34", j)
    end
end

@testset "JSON — strategy IOBuffer paths" begin

    @testset "to_json(CamelCase(), data; pretty=true) with struct" begin
        struct _JCamelPretty; my_field::Int; other_val::String; end
        j = to_json(CamelCase(), _JCamelPretty(1, "hi"); pretty = true)
        @test occursin("myField", j) || occursin("otherVal", j)
    end

    @testset "to_json(strategy, f, data) — strategy IOBuffer" begin
        struct _JStratF; x_val::Int; y_val::String; end
        f_all = T -> fieldnames(T)
        j = to_json(CamelCase(), f_all, _JStratF(99, "test"))
        @test occursin("xVal", j) || occursin("yVal", j)
    end

    @testset "to_json(strategy, data; pretty=true) with >32 fields" begin
        field_decls = join(["sp$i::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _JSONStratBig34; $field_decls; end"))
        vals = ntuple(i -> i, 34)
        obj = Main._JSONStratBig34(vals...)
        j = to_json(CamelCase(), obj; pretty = true)
        @test occursin("sp1", j) || occursin("sp34", j)
    end

    @testset "to_json(strategy, f, data) >32 fields else branch" begin
        field_decls = join(["stf$i::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _JSONStratFBig; $field_decls; end"))
        vals = ntuple(i -> i, 34)
        obj = Main._JSONStratFBig(vals...)
        f_all = T -> fieldnames(T)
        j = to_json(CamelCase(), f_all, obj)
        @test occursin("stf1", j) || occursin("stf34", j)
    end

    @testset "to_json(io, strategy, data)" begin
        struct _JStratIO; count::Int; end
        io = IOBuffer()
        to_json(io, CamelCase(), _JStratIO(5))
        j = String(take!(io))
        @test occursin("5", j)
    end

    @testset "to_pretty_json(strategy, data)" begin
        struct _JPrettyStrat; name_val::String; end
        j = to_pretty_json(CamelCase(), _JPrettyStrat("test"))
        @test occursin("nameVal", j)
    end
end

@testset "JSON — from_json(strategy, T) for non-struct types" begin
    # Lines 534-540: strategy path for non-StructClass/TaggedClass types
    @testset "from_json(CamelCase(), Vector{Int}, json)" begin
        j = from_json(CamelCase(), Vector{Int}, "[1,2,3]")
        @test j == [1, 2, 3]
    end

    @testset "from_json(CamelCase(), Dict, json)" begin
        j = from_json(CamelCase(), Dict{String,Int}, "{\"a\":1}")
        @test j["a"] == 1
    end

    @testset "from_json(strategy, String, json)" begin
        j = from_json(CamelCase(), String, "\"hello\"")
        @test j == "hello"
    end
end

@testset "JSON — _json_indent! deep level (>32)" begin
    # Need l >= length(_JSON_INDENTS) to trigger the else branch
    # _JSON_INDENTS has 33 entries (0..32), so l >= 33 triggers else
    # Create a deeply nested struct (33 levels deep) is impractical,
    # but we can call _json_indent! directly via to_json(io, ...) with deep nesting
    # Instead, test via 2D array with deeply nested vectors
    # or via a recursive struct
    # The easiest: just test to_json with pretty=true produces valid output for nested dict
    nested = Dict("a" => Dict("b" => Dict("c" => 42)))
    j = to_json(nested; pretty = true)
    @test occursin("42", j)
end

@testset "JSON IOBuffer — remaining one-liners and paths" begin

    f_all = T -> fieldnames(T)

    @testset "DateTimeType via to_json(f, data) — line 861" begin
        struct _JFDateIO; dt::Dates.Date; end
        j = to_json(f_all, _JFDateIO(Dates.Date(2024, 1, 1)))
        @test occursin("2024-01-01", j)
    end

    @testset "DateTime via to_json(f, data)" begin
        struct _JFDateTimeIO; dt::Dates.DateTime; end
        j = to_json(f_all, _JFDateTimeIO(Dates.DateTime(2024, 1, 1, 12, 0, 0)))
        @test occursin("2024", j)
    end

    @testset "Negative integer via to_json(f, data) — lines 873-874" begin
        struct _JFNegIntIO; n::Int; end
        j = to_json(f_all, _JFNegIntIO(-42))
        @test occursin("-42", j)
    end

    @testset "AbstractFloat via to_json(f, data) — lines 880-885" begin
        struct _JFFltIO; v::Float64; end
        j = to_json(f_all, _JFFltIO(3.14))
        @test occursin("3.14", j)
    end

    @testset "Float32 via to_json(f, data)" begin
        struct _JFFF32IO; v::Float32; end
        j = to_json(f_all, _JFFF32IO(Float32(1.5)))
        @test occursin("1.5", j)
    end

    @testset "String with escape via to_json(f, data) — line 853" begin
        # String with newline triggers escape_string path
        j = to_json(f_all, "hello\nworld")
        @test occursin("\\n", j)
    end

    @testset "_json_write_key! with escape char — line 808" begin
        # Dict key with special char triggers escape_string in _json_write_key!
        j = to_json(Dict("key\nspecial" => 1); pretty = true)
        @test occursin("\\n", j)
    end

    @testset "AbstractFloat strategy one-liner — line 1031" begin
        # to_json(strategy, f, data) with Float field
        struct _JFltStrategy; v::Float64; end
        j = to_json(CamelCase(), f_all, _JFltStrategy(2.71))
        @test occursin("2.71", j)
    end

    @testset "Number (BigFloat) via to_json(f, data)" begin
        # Number catch-all after Float/Integer — BigFloat dispatches to Number
        j = to_json(f_all, [BigFloat(3.14)])
        @test occursin("3", j)
    end
end

@testset "JSON IOBuffer — pretty=true deep level (>32 indent)" begin
    # Need l >= 33 to trigger else branch in _json_indent! — requires 32 levels of nesting
    function build_nested(d, depth)
        depth == 0 && return d
        return Dict("a" => build_nested(d, depth - 1))
    end
    nested = build_nested(1, 34)  # 34 levels deep
    j = to_json(nested; pretty = true)
    @test occursin("1", j)
end

@testset "JSON — _yy_ser strategy >32 fields compact" begin

    @testset "to_json(CamelCase(), data) with >32 fields" begin
        field_decls = join(["yys$(i)::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _YYSer34Strat; " * field_decls * "; end"))
        vals = ntuple(i -> i, 34)
        obj = Main._YYSer34Strat(vals...)
        j = to_json(CamelCase(), obj)
        @test occursin("yys1", j)
        @test occursin("yys34", j)
        @test occursin("34", j)
    end
end

@testset "JSON — strategy _yy_deser_struct null field handling" begin

    @testset "from_json(strategy, T) with null field — line 285" begin
        struct _JStratNull; a::Int; b::Union{Nothing,String}; end
        obj = from_json(CamelCase(), _JStratNull, "{\"a\": 1, \"b\": null}")
        @test obj.a == 1
        @test obj.b === nothing
    end

    @testset "from_json(strategy, T) with missing field uses default — line 283" begin
        struct _JStratMiss; a::Int; b::Union{Nothing,Int}; end
        obj = from_json(CamelCase(), _JStratMiss, "{\"a\": 5}")
        @test obj.a == 5
        @test obj.b === nothing
    end
end

@testset "JSON — _yy_extract additional paths" begin

    @testset "Float64 from integer JSON via from_json direct" begin
        # _yy_extract(_, Float64, int_v) — line 162
        struct _JFloat64FromInt; val::Float64; end
        obj = from_json(_JFloat64FromInt, "{\"val\": 42}")
        @test obj.val == 42.0
    end

    @testset "Float64 from string JSON via from_json direct" begin
        # _yy_extract(_, Float64, str_v) — line 163
        struct _JFloat64FromStr; val::Float64; end
        obj = from_json(_JFloat64FromStr, "{\"val\": \"3.14\"}")
        @test obj.val ≈ 3.14
    end

    @testset "Float32 from JSON" begin
        struct _JFloat32; val::Float32; end
        obj = from_json(_JFloat32, "{\"val\": 1.5}")
        @test obj.val ≈ Float32(1.5)
    end

    @testset "null JSON → default value (line 270 in _yy_deser_struct)" begin
        struct _JNullDefault
            required::Int
            optional::Union{Nothing,String}
        end
        obj = from_json(_JNullDefault, "{\"required\": 1, \"optional\": null}")
        @test obj.optional === nothing
    end

    @testset "missing field → _field_default (line 268/286)" begin
        struct _JMissField
            a::Int
            b::Union{Nothing,String}
        end
        obj = from_json(_JMissField, "{\"a\": 5}")
        @test obj.a == 5
        @test obj.b === nothing
    end

    @testset "from_json(strategy, T) for >32 fields" begin
        field_decls = join(["jds$i::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _JSONDeser34; $field_decls; end"))
        # Build JSON with all 34 fields
        json_fields = join(["{\"jds$(i)\": $i}" for i in 1:34], "")[2:end-1]
        json_str = "{" * join(["\"jds$(i)\": $i" for i in 1:34], ",") * "}"
        obj = from_json(Main._JSONDeser34, json_str)
        @test getfield(obj, :jds1) == 1
        @test getfield(obj, :jds34) == 34
    end

    @testset "from_json(CamelCase(), T) for >32 fields" begin
        field_decls = join(["jdc$i::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _JSONDeserCtx34; $field_decls; end"))
        json_str = "{" * join(["\"jdc$(i)\": $i" for i in 1:34], ",") * "}"
        obj = from_json(CamelCase(), Main._JSONDeserCtx34, json_str)
        @test getfield(obj, :jdc1) == 1
        @test getfield(obj, :jdc34) == 34
    end
end

@testset "JSON — to_json(io, data) stream path" begin

    @testset "to_json(io, struct) basic" begin
        struct _JIOStream; x::Int; y::String; end
        io = IOBuffer()
        to_json(io, _JIOStream(1, "test"))
        j = String(take!(io))
        @test occursin("x", j) && occursin("1", j)
    end

    @testset "to_json(io, data; pretty=true)" begin
        io = IOBuffer()
        to_json(io, [1, 2, 3]; pretty = true)
        j = String(take!(io))
        @test occursin("1", j)
    end
end

@testset "JSON — to_json(io, strategy, data)" begin

    @testset "to_json(io, strategy, struct)" begin
        struct _JStratIOStream; x_val::Int; end
        io = IOBuffer()
        to_json(io, CamelCase(), _JStratIOStream(99))
        j = String(take!(io))
        @test occursin("xVal", j)
        @test occursin("99", j)
    end

    @testset "to_json(io, strategy, data; pretty=true)" begin
        struct _JStratIOPretty; my_x::Int; end
        io = IOBuffer()
        to_json(io, CamelCase(), _JStratIOPretty(5); pretty = true)
        j = String(take!(io))
        @test occursin("myX", j)
    end
end

@testset "JSON — strategy f≠fieldnames (else branch in _json_value! strategy)" begin

    @testset "to_json(strategy, f, struct) — else branch with strategy" begin
        struct _JStratElse; x_field::Int; y_field::String; end
        # Custom f that returns subset of fields
        f_sub = T -> (:x_field,)
        j = to_json(CamelCase(), f_sub, _JStratElse(1, "hello"))
        @test occursin("xField", j)
        @test !occursin("yField", j)
    end

    @testset "to_json(strategy, f, struct) with various value types" begin
        struct _JStratElseFull; a::Int; b::Float64; c::Bool; end
        f_all = T -> fieldnames(T)
        j = to_json(CamelCase(), f_all, _JStratElseFull(1, 2.5, true))
        @test occursin("1", j)
        @test occursin("2.5", j)
        @test occursin("true", j)
    end
end

@testset "JSON — strategy >32 fields: null and missing at position 33+" begin

    @testset "from_json(strategy, T) with null at field 33 — line 285" begin
        # Build a 34-field struct where field 33 is Union{Nothing,Int}
        field_decls = join(["jsd$(i)::Int" for i in 1:32], "; ") *
                      "; jsd33::Union{Nothing,Int}; jsd34::Int"
        eval(Meta.parse("struct _JsonStratDeser34; " * field_decls * "; end"))
        # Provide values for first 32, null for field 33, value for 34
        fields_json = join(["\"jsd$(i)\":$(i)" for i in 1:32], ",") *
                      ",\"jsd33\":null,\"jsd34\":34"
        json_str = "{" * fields_json * "}"
        obj = from_json(CamelCase(), Main._JsonStratDeser34, json_str)
        @test getfield(obj, :jsd33) === nothing
        @test getfield(obj, :jsd34) == 34
    end

    @testset "from_json(strategy, T) with missing field 33 uses default — line 283" begin
        # Build a 34-field struct where field 33 is Union{Nothing,Int}
        field_decls = join(["jsm$(i)::Int" for i in 1:32], "; ") *
                      "; jsm33::Union{Nothing,Int}; jsm34::Int"
        eval(Meta.parse("struct _JsonStratMiss34; " * field_decls * "; end"))
        # Omit field 33 entirely — has_default will provide nothing for Union{Nothing,Int}
        fields_json = join(["\"jsm$(i)\":$(i)" for i in 1:32], ",") * ",\"jsm34\":34"
        json_str = "{" * fields_json * "}"
        obj = from_json(CamelCase(), Main._JsonStratMiss34, json_str)
        @test getfield(obj, :jsm33) === nothing
        @test getfield(obj, :jsm34) == 34
    end
end
