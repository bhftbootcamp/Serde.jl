@testset "Trait defaults" begin
    struct _TraitTest; a::Int; end

    @test Serde.deser_name(_TraitTest, Val(:a)) === :a
    @test Serde.has_default(_TraitTest, Val(:a)) === false
    @test Serde.deser_default(_TraitTest, Val(:a)) === nothing
    @test Serde.isempty_value(_TraitTest, Val(:a), 0) === false
    @test Serde.deser_validate(_TraitTest, Val(:a), 42) === nothing

    @test Serde.ser_name(_TraitTest, Val(:a)) === :a
    @test Serde.ser_value(_TraitTest, Val(:a), 42) === 42
    @test Serde.ser_type(_TraitTest, 42) === 42
    @test Serde.ser_skip(_TraitTest, Val(:a)) === false
    @test Serde.ser_skip(_TraitTest, Val(:a), 42) === false

    @test Serde.tag_key(_TraitTest) === nothing
    @test Serde.tag_subtypes(_TraitTest) === ()
end

@testset "Trait nulltype" begin
    @test Serde.nulltype(String) === nothing
    @test Serde.nulltype(Int) === nothing
    @test Serde.nulltype(Missing) === missing
    @test Serde.nulltype(Union{Nothing,Int}) === nothing
    @test Serde.nulltype(Union{Missing,Int}) === missing
end

@testset "Manual trait overrides" begin
    struct _ManualTraits
        user_name::String
        score::Int
    end

    Serde.deser_name(::Type{_ManualTraits}, ::Val{:user_name}) = :userName
    Serde.ser_name(::Type{_ManualTraits}, ::Val{:user_name}) = :userName
    Serde.has_default(::Type{_ManualTraits}, ::Val{:score}) = true
    Serde.deser_default(::Type{_ManualTraits}, ::Val{:score}) = 0

    obj = Serde.deser(_ManualTraits, Dict("userName" => "test"))
    @test obj.user_name == "test"
    @test obj.score == 0
end
