@testset "Tagged unions" begin
    abstract type _TUMessage end
    Serde.ClassType(::Type{_TUMessage}) = Serde.TaggedClass()
    Serde.tag_key(::Type{<:_TUMessage}) = "type"

    struct _TURequest <: _TUMessage
        id::Int
        method::String
    end
    register_tagged_subtype(_TUMessage, "_TURequest", _TURequest)

    struct _TUResponse <: _TUMessage
        id::Int
        result::String
    end
    register_tagged_subtype(_TUMessage, "_TUResponse", _TUResponse)

    @testset "Dispatch by tag" begin
        json_req = "{\"type\": \"_TURequest\", \"id\": 1, \"method\": \"GET\"}"
        obj = from_json(_TUMessage, json_req)
        @test obj isa _TURequest
        @test obj.id == 1
        @test obj.method == "GET"

        json_resp = "{\"type\": \"_TUResponse\", \"id\": 2, \"result\": \"OK\"}"
        obj2 = from_json(_TUMessage, json_resp)
        @test obj2 isa _TUResponse
        @test obj2.id == 2
        @test obj2.result == "OK"
    end

    @testset "tag_key is set" begin
        @test Serde.tag_key(_TUMessage) == "type"
    end

    @testset "tag_subtypes registered" begin
        subs = Serde.tag_subtypes(_TUMessage)
        @test length(subs) >= 2
    end
end

@testset "Deser — TaggedClass TypeMismatchError paths" begin

    @testset "Unknown tag value throws TypeMismatchError — line 283" begin
        abstract type _TagMismatch end
        Serde.ClassType(::Type{<:_TagMismatch}) = Serde.TaggedClass()
        Serde.tag_key(::Type{<:_TagMismatch}) = "kind"

        struct _TagMismatchA <: _TagMismatch
            val::Int
        end
        register_tagged_subtype(_TagMismatch, "a", _TagMismatchA)

        @test_throws TypeMismatchError Serde.deser(
            _TagMismatch,
            Dict("kind" => "unknown_tag", "val" => 1)
        )
    end

    @testset "Missing tag key throws TypeMismatchError" begin
        abstract type _TagMissing end
        Serde.ClassType(::Type{<:_TagMissing}) = Serde.TaggedClass()
        Serde.tag_key(::Type{<:_TagMissing}) = "type"

        struct _TagMissingA <: _TagMissing
            id::Int
        end
        register_tagged_subtype(_TagMissing, "a", _TagMissingA)

        # Dict without tag key → tag_val is nothing → TypeMismatchError
        @test_throws TypeMismatchError Serde.deser(
            _TagMissing,
            Dict("id" => 1)
        )
    end
end

@testset "register_tagged_subtype — runtime registry (no method overwrites)" begin
    # Registering multiple parents and re-registering existing tags should not
    # produce method-overwrite warnings or lose entries.
    abstract type _Reg1 end
    abstract type _Reg2 end
    Serde.ClassType(::Type{<:_Reg1}) = Serde.TaggedClass()
    Serde.ClassType(::Type{<:_Reg2}) = Serde.TaggedClass()
    Serde.tag_key(::Type{<:_Reg1}) = "k"
    Serde.tag_key(::Type{<:_Reg2}) = "k"

    struct _Reg1A <: _Reg1; v::Int; end
    struct _Reg1B <: _Reg1; v::Int; end
    struct _Reg2A <: _Reg2; v::Int; end

    register_tagged_subtype(_Reg1, "a", _Reg1A)
    register_tagged_subtype(_Reg1, "b", _Reg1B)
    register_tagged_subtype(_Reg2, "a", _Reg2A)

    @test length(Serde.tag_subtypes(_Reg1)) == 2
    @test length(Serde.tag_subtypes(_Reg2)) == 1

    # Re-registering the same tag updates rather than appending duplicates.
    struct _Reg1A2 <: _Reg1; v::Int; end
    register_tagged_subtype(_Reg1, "a", _Reg1A2)
    @test length(Serde.tag_subtypes(_Reg1)) == 2
    @test from_json(_Reg1, "{\"k\":\"a\",\"v\":1}") isa _Reg1A2
end

@testset "Numeric string parse failure throws TypeMismatchError, not nothing" begin
    struct _NumParse; n::Int; end
    @test_throws TypeMismatchError from_json(_NumParse, "{\"n\":\"abc\"}")
    @test_throws TypeMismatchError Serde.deser(_NumParse, Dict("n" => "abc"))
end

@testset "register_tagged_subtype — most-specific parent wins" begin
    # Regression: registry iteration order was non-deterministic, so when a
    # type T satisfied `T <: P1` AND `T <: P2` the result depended on dict
    # iteration order. Now we always pick the most specific registered parent.
    abstract type _MS1 end
    abstract type _MS2 <: _MS1 end
    Serde.ClassType(::Type{<:_MS1}) = Serde.TaggedClass()
    Serde.tag_key(::Type{<:_MS1}) = "k"

    struct _MSBroad <: _MS2; v::Int; end   # registered only under _MS1
    struct _MSNarrow <: _MS2; v::Int; end  # registered under the narrower _MS2

    register_tagged_subtype(_MS1, "x", _MSBroad)
    register_tagged_subtype(_MS2, "x", _MSNarrow)

    # When querying _MS2, the narrower registration must win.
    @test from_json(_MS2, "{\"k\":\"x\",\"v\":1}") isa _MSNarrow
    # When querying _MS1, only its own registration is visible.
    @test from_json(_MS1, "{\"k\":\"x\",\"v\":1}") isa _MSBroad
end

@testset "Tagged union deser through every format" begin
    # Regression: from_query previously called `fieldnames(T)` directly,
    # which raises for abstract types (the typical TaggedClass target).
    abstract type _FmtEvt end
    Serde.ClassType(::Type{<:_FmtEvt}) = Serde.TaggedClass()
    Serde.tag_key(::Type{<:_FmtEvt}) = "kind"
    struct _FmtLogin <: _FmtEvt
        kind::String
        user::String
    end
    register_tagged_subtype(_FmtEvt, "login", _FmtLogin)

    @test from_json(_FmtEvt, """{"kind":"login","user":"x"}""") isa _FmtLogin
    @test from_msgpack(_FmtEvt, to_msgpack(Dict("kind"=>"login","user"=>"x"))) isa _FmtLogin
    @test from_bson(_FmtEvt, to_bson(Dict("kind"=>"login","user"=>"x"))) isa _FmtLogin
    @test from_toml(_FmtEvt, "kind=\"login\"\nuser=\"x\"\n") isa _FmtLogin
    @test from_yaml(_FmtEvt, "kind: login\nuser: x\n") isa _FmtLogin
    @test from_query(_FmtEvt, "kind=login&user=x") isa _FmtLogin
    @test from_xml(_FmtEvt, "<r kind=\"login\" user=\"x\"/>") isa _FmtLogin
end

@testset "Tagged union deser via MsgPack / BSON does not stack overflow" begin
    # Regression: `deser(strategy, ::TaggedClass, T, data)` used to recurse via
    # `deser(strategy, ST, data)`, which re-dispatched to TaggedClass (since
    # `ClassType(<:ST) = TaggedClass()` matches every subtype of the parent).
    # The fix routes the matched subtype to `StructClass()` directly.
    abstract type _BinEvt end
    Serde.ClassType(::Type{<:_BinEvt}) = Serde.TaggedClass()
    Serde.tag_key(::Type{<:_BinEvt}) = "kind"
    struct _BinLogin <: _BinEvt; user::String; end
    register_tagged_subtype(_BinEvt, "login", _BinLogin)

    # The dispatch table now reaches the concrete subtype after one hop.
    @test from_msgpack(_BinEvt, to_msgpack(Dict("kind"=>"login", "user"=>"a"))) isa _BinLogin
    @test from_bson(_BinEvt, to_bson(Dict("kind"=>"login", "user"=>"b"))) isa _BinLogin
end

@testset "Strategy-aware tag_key / tag_subtypes" begin
    abstract type _SEvt end
    Serde.ClassType(::Type{<:_SEvt}) = Serde.TaggedClass()
    Serde.tag_key(::Type{<:_SEvt}) = "kind"
    struct _SLogin <: _SEvt; user::String; end
    struct _SLegacy <: _SEvt; note::String; end
    register_tagged_subtype(_SEvt, "login", _SLogin)

    # A strategy that picks a different discriminator field AND a different
    # subtype table. Both `tag_key` and `tag_subtypes` are strategy-aware now.
    struct _ApiStrat end
    Serde.tag_key(::_ApiStrat, ::Type{<:_SEvt}) = "apiKind"
    Serde.tag_subtypes(::_ApiStrat, ::Type{<:_SEvt}) = ("legacy" => _SLegacy,)

    @test from_json(_ApiStrat(), _SEvt, "{\"apiKind\":\"legacy\",\"note\":\"old\"}") isa _SLegacy

    # Default strategy still uses the default tag_key + registry.
    @test from_json(_SEvt, "{\"kind\":\"login\",\"user\":\"ada\"}") isa _SLogin

    # `With` composes: first non-`nothing` wins for tag_key, first non-empty
    # for tag_subtypes.
    struct _NoTagStrat end  # overrides nothing
    @test from_json(With(_NoTagStrat(), _ApiStrat()), _SEvt,
                    "{\"apiKind\":\"legacy\",\"note\":\"old\"}") isa _SLegacy
end

@testset "Enum string mismatch surfaces TypeMismatchError" begin
    # Regression: `deser(strategy, ::PrimitiveClass, ::Type{T}, ::Symbol) where {T<:Enum}`
    # returned `nothing` when the name was unknown, hiding the error.
    @enum _EnumColor _RED _GREEN _BLUE
    struct _EnumS; c::_EnumColor; end
    @test_throws TypeMismatchError from_json(_EnumS, "{\"c\":\"PURPLE\"}")
    @test_throws TypeMismatchError Serde.deser(_EnumS, Dict("c" => "PURPLE"))
end
