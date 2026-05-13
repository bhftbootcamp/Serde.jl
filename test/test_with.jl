@testset "With strategy composer" begin

    # ── ser_name / deser_name: chain of responsibility ──────────────────────

    @testset "With(CamelCase()) renames fields" begin
        struct _WithCamel
            order_id::Int
            total_amount::Float64
        end
        w = With(CamelCase())
        json = to_json(w, _WithCamel(1, 99.9))
        @test contains(json, "\"orderId\"")
        @test contains(json, "\"totalAmount\"")
        @test !contains(json, "order_id")

        obj = from_json(w, _WithCamel, "{\"orderId\":7,\"totalAmount\":3.14}")
        @test obj.order_id == 7
        @test obj.total_amount == 3.14
    end

    @testset "With(PascalCase()) renames fields" begin
        struct _WithPascal
            user_name::String
        end
        w = With(PascalCase())
        json = to_json(w, _WithPascal("Alice"))
        @test contains(json, "\"UserName\"")

        obj = from_json(w, _WithPascal, "{\"UserName\":\"Bob\"}")
        @test obj.user_name == "Bob"
    end

    @testset "naming composes as a chain" begin
        struct _WithChain
            user_id::Int
            full_name::String
        end
        # A custom prefix-and-capitalize strategy. The chain feeds it the
        # previous step's output, so combining with CamelCase produces a
        # composed result rather than dropping one of the two transforms.
        struct _ApiPrefix end
        Serde.ser_name(::_ApiPrefix, ::Type{T}, ::Val{x}) where {T,x}   =
            Symbol("api" * uppercasefirst(string(x)))
        Serde.deser_name(::_ApiPrefix, ::Type{T}, ::Val{x}) where {T,x} =
            Symbol("api" * uppercasefirst(string(x)))

        w = With(CamelCase(), _ApiPrefix())
        # snake_case → camelCase → prefix-capitalize
        @test Serde.ser_name(w, _WithChain, Val(:user_id))   === :apiUserId
        @test Serde.ser_name(w, _WithChain, Val(:full_name)) === :apiFullName

        # End-to-end JSON round trip — was impossible under the old first-wins
        # semantic where one of the two transforms always got dropped.
        json = to_json(w, _WithChain(42, "Ada"))
        @test contains(json, "\"apiUserId\":42")
        @test contains(json, "\"apiFullName\":\"Ada\"")
        back = from_json(w, _WithChain, json)
        @test back.user_id == 42
        @test back.full_name == "Ada"
    end

    @testset "non-renaming strategies are transparent in the chain" begin
        struct _WithIdentity
            x::Int
        end
        # A strategy that doesn't override `ser_name` falls through to the
        # default `ser_name(strategy, T, Val(x)) = x`, returning whatever the
        # previous step produced — i.e. it's a no-op pass.
        struct _NoNameStrat end
        w = With(CamelCase(), _NoNameStrat(), CamelCase())
        # CamelCase of `:x` is `:x` (no underscores); _NoNameStrat passes
        # through; CamelCase again is `:x`. Final result: `:x`.
        @test Serde.ser_name(w, _WithIdentity, Val(:x)) === :x
    end

    @testset "naming chain treats `nothing` as pass-through" begin
        # Regression: a strategy returning `nothing` from `ser_name` used to
        # be coerced to the literal Symbol `:nothing` (via `_to_name_sym`),
        # poisoning the chain. The chain now skips the strategy and carries
        # the previous name forward.
        struct _WithNothingPass; user_id::Int; end

        struct _PassThrough end
        Serde.ser_name(::_PassThrough, ::Type{T}, ::Val{x}) where {T,x} = nothing

        # On its own, _PassThrough is a no-op: the field name is unchanged.
        @test Serde.ser_name(With(_PassThrough()), _WithNothingPass, Val(:user_id)) === :user_id
        # In a chain, the surrounding strategies still apply.
        @test Serde.ser_name(With(_PassThrough(), CamelCase()), _WithNothingPass, Val(:user_id)) === :userId
        @test Serde.ser_name(With(CamelCase(), _PassThrough()), _WithNothingPass, Val(:user_id)) === :userId
    end

    @testset "naming chain bypasses type-level overrides (documented)" begin
        struct _WithFallthrough
            foo::Int
        end
        Serde.ser_name(::Type{_WithFallthrough}, ::Val{:foo}) = :FOO
        # With's chain calls each strategy's `ser_name(strategy, T, Val(x))`
        # in sequence. Each strategy defaults to "return the input unchanged",
        # so the final result is the original field name `:foo` (or whatever
        # the last strategy returns) — NOT the type-level override `:FOO`.
        # The type-level override still applies in the no-strategy path.
        @test Serde.ser_name(With(CamelCase()), _WithFallthrough, Val(:foo)) === :foo
        @test Serde.ser_name(_WithFallthrough, Val(:foo)) === :FOO
    end

    # ── ser_skip: OR ──────────────────────────────────────────────────────────

    @testset "ser_skip OR: type-level skip propagates through With" begin
        struct _WithSkip
            visible::Int
            hidden::Int
        end
        Serde.ser_skip(::Type{_WithSkip}, ::Val{:hidden}) = true

        w = With(CamelCase())
        json = to_json(w, _WithSkip(1, 2))
        @test contains(json, "visible")
        @test !contains(json, "hidden")
    end

    @testset "ser_skip OR: custom strategy skip" begin
        struct _WithSkipCtx
            a::Int
            b::Int
        end

        struct _SkipB end
        Serde.ser_skip(::_SkipB, ::Type{_WithSkipCtx}, ::Val{:b}, v) = true

        w = With(CamelCase(), _SkipB())
        json = to_json(w, _WithSkipCtx(1, 2))
        @test contains(json, "\"a\"")
        @test !contains(json, "\"b\"")
    end

    # ── ser_value: chain ──────────────────────────────────────────────────────

    @testset "ser_value chain: transformations compose" begin
        struct _WithSerVal
            count::Int
        end

        struct _Double end
        struct _AddTen end
        Serde.ser_value(::_Double,  ::Type{_WithSerVal}, ::Val{:count}, v::Int) = v * 2
        Serde.ser_value(::_AddTen, ::Type{_WithSerVal}, ::Val{:count}, v::Int) = v + 10

        # chain: Double first → 3*2=6, then AddTen → 6+10=16
        w = With(_Double(), _AddTen())
        json = to_json(w, _WithSerVal(3))
        @test contains(json, "16")
    end

    # ── has_default / deser_default: first-wins ───────────────────────────────

    @testset "With provides strategy-level default" begin
        struct _WithDefault
            name::String
            score::Int
        end

        struct _ScoreDefault end
        Serde.has_default(::_ScoreDefault, ::Type{_WithDefault}, ::Val{:score}) = true
        Serde.deser_default(::_ScoreDefault, ::Type{_WithDefault}, ::Val{:score}) = 100

        w = With(CamelCase(), _ScoreDefault())
        obj = from_json(w, _WithDefault, "{\"name\":\"Alice\"}")
        @test obj.name == "Alice"
        @test obj.score == 100
    end

    @testset "first strategy default wins" begin
        struct _WithTwoDefaults
            x::Int
        end

        struct _Default5 end
        struct _Default9 end
        Serde.has_default(::_Default5, ::Type{_WithTwoDefaults}, ::Val{:x}) = true
        Serde.deser_default(::_Default5, ::Type{_WithTwoDefaults}, ::Val{:x}) = 5
        Serde.has_default(::_Default9, ::Type{_WithTwoDefaults}, ::Val{:x}) = true
        Serde.deser_default(::_Default9, ::Type{_WithTwoDefaults}, ::Val{:x}) = 9

        # _Default5 is first → wins
        w = With(_Default5(), _Default9())
        obj = from_json(w, _WithTwoDefaults, "{}")
        @test obj.x == 5
    end

    # ── isempty_value: OR ─────────────────────────────────────────────────────

    @testset "isempty_value OR: any strategy can mark value empty" begin
        struct _WithEmpty
            value::Union{Nothing,Int}
        end

        struct _ZeroIsEmpty end
        Serde.isempty_value(::_ZeroIsEmpty, ::Type{_WithEmpty}, ::Val{:value}, v::Int) = v == 0

        w = With(_ZeroIsEmpty())
        obj = from_json(w, _WithEmpty, "{\"value\":0}")
        @test isnothing(obj.value)

        obj2 = from_json(w, _WithEmpty, "{\"value\":5}")
        @test obj2.value == 5
    end

    # ── deser_transform: chain ────────────────────────────────────────────────

    @testset "deser_transform chain: transformations compose" begin
        struct _WithTransform
            celsius::Float64
        end

        struct _FToC end
        struct _Round end
        # Convert Fahrenheit to Celsius
        Serde.deser_transform(::_FToC, ::Type{_WithTransform}, ::Type{Float64}, v::Number) = (v - 32) * 5 / 9
        # Round to 1 decimal
        Serde.deser_transform(::_Round, ::Type{_WithTransform}, ::Type{Float64}, v::Number) = round(Float64(v); digits=1)

        w = With(_FToC(), _Round())
        # 212°F → 100°C → 100.0
        obj = from_json(w, _WithTransform, "{\"celsius\":212}")
        @test obj.celsius == 100.0
    end

    # ── deser_validate: all ───────────────────────────────────────────────────

    @testset "deser_validate all: both validators run" begin
        struct _WithValidate
            x::Int
        end

        struct _MustBePositive end
        struct _MustBeLt100 end
        Serde.deser_validate(::_MustBePositive, ::Type{_WithValidate}, ::Val{:x}, v::Int) =
            v > 0 || throw(Serde.ValidationError(_WithValidate, :x, v, "must be positive"))
        Serde.deser_validate(::_MustBeLt100, ::Type{_WithValidate}, ::Val{:x}, v::Int) =
            v < 100 || throw(Serde.ValidationError(_WithValidate, :x, v, "must be < 100"))

        w = With(_MustBePositive(), _MustBeLt100())
        obj = from_json(w, _WithValidate, "{\"x\":50}")
        @test obj.x == 50

        @test_throws Serde.ValidationError from_json(w, _WithValidate, "{\"x\":-1}")
        @test_throws Serde.ValidationError from_json(w, _WithValidate, "{\"x\":200}")
    end

    # ── Three and more strategies ─────────────────────────────────────────────

    @testset "three strategies combined" begin
        struct _WithThree
            field_one::String
            skip_me::Int
            transform_me::Int
        end

        struct _SkipSkipMe end
        struct _DoubleTransformMe end
        Serde.ser_skip(::_SkipSkipMe, ::Type{_WithThree}, ::Val{:skip_me}, v) = true
        Serde.ser_value(::_DoubleTransformMe, ::Type{_WithThree}, ::Val{:transform_me}, v::Int) = v * 2

        w = With(CamelCase(), _SkipSkipMe(), _DoubleTransformMe())
        json = to_json(w, _WithThree("hello", 99, 5))
        @test contains(json, "\"fieldOne\"")      # camelCase from CamelCase
        @test !contains(json, "skipMe")           # skipped
        @test !contains(json, "skip_me")
        @test contains(json, "10")                # 5 * 2 = 10
    end

    # ── Round-trip via multiple formats ──────────────────────────────────────

    @testset "With(CamelCase()) round-trip JSON" begin
        struct _WithRoundtrip
            first_name::String
            last_name::String
            age::Int
        end
        w = With(CamelCase())
        original = _WithRoundtrip("Alice", "Smith", 30)
        json = to_json(w, original)
        recovered = from_json(w, _WithRoundtrip, json)
        @test recovered.first_name == original.first_name
        @test recovered.last_name == original.last_name
        @test recovered.age == original.age
    end

    @testset "With(CamelCase()) round-trip Query" begin
        struct _WithRoundtripQ
            user_id::Int
            page_size::Int
        end
        w = With(CamelCase())
        original = _WithRoundtripQ(42, 10)
        q = to_query(w, original; escape = false)
        @test contains(q, "userId=42")
        @test contains(q, "pageSize=10")
    end

    @testset "With empty tuple" begin
        struct _WithEmpty2
            x::Int
        end
        # With() with no strategies — should behave like DefaultStrategy
        w = With()
        @test Serde.ser_name(w, _WithEmpty2, Val(:x)) == :x
        @test Serde.ser_skip(w, _WithEmpty2, Val(:x)) == false
        json = to_json(w, _WithEmpty2(42))
        @test contains(json, "\"x\":42")
    end

end

@testset "with.jl — _with_has_default empty tuple base case" begin

    @testset "has_default(With(), T, Val(:x)) returns false — line 99" begin
        struct _WHD_Type
            x::Int
        end
        # With() has empty ctxs tuple; _with_has_default((), ...) → line 99 → false
        w = With()
        @test Serde.has_default(w, _WHD_Type, Val(:x)) == false
    end

    @testset "has_default(With(strategy_no_default), T, Val(:x)) — exhausts all, hits line 99" begin
        struct _WHD_Type2
            y::Int
        end
        # CamelCase never provides defaults — iterates through ctxs, reaches empty tuple
        w = With(CamelCase())
        @test Serde.has_default(w, _WHD_Type2, Val(:y)) == false
    end
end
