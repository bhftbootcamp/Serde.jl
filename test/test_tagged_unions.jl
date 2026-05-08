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
