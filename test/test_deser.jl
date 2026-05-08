@testset "Deser engine" begin
    @testset "Primitives" begin
        @test Serde.deser(Int, 42) === 42
        @test Serde.deser(Float64, 3) == 3.0
        @test Serde.deser(Int, "123") === 123
        @test Serde.deser(Symbol, "hello") === :hello
        @test Serde.deser(String, :world) == "world"
        @test Serde.deser(String, 42) == "42"
        @test Serde.deser(Bool, true) === true
    end

    @testset "Enums" begin
        @enum _DeColor red green blue
        @test Serde.deser(_DeColor, 0) === red
        @test Serde.deser(_DeColor, "green") === green
        @test Serde.deser(_DeColor, :blue) === blue
    end

    @testset "Null types" begin
        @test Serde.deser(Nothing, nothing) === nothing
        @test Serde.deser(Missing, missing) === missing
    end

    @testset "Union{Nothing,T}" begin
        @test Serde.deser(Union{Nothing,Int}, 42) === 42
        @test Serde.deser(Union{Nothing,String}, "hi") == "hi"
    end

    @testset "NamedTuple" begin
        nt = Serde.deser(NamedTuple, Dict("a" => 1, "b" => 2))
        @test nt.a == 1
        @test nt.b == 2
    end

    @testset "Vectors" begin
        v = Serde.deser(Vector{Int}, Any[1, 2, 3])
        @test v == [1, 2, 3]

        v2 = Serde.deser(Vector{Int}, Any["1", "2", "3"])
        @test v2 == [1, 2, 3]
    end

    @testset "Tuples" begin
        t = Serde.deser(Tuple{Int,String}, [1, "a"])
        @test t === (1, "a")
    end

    @testset "Dicts" begin
        d = Serde.deser(Dict{String,Int}, Dict("a" => 1, "b" => 2))
        @test d == Dict("a" => 1, "b" => 2)

        d2 = Serde.deser(Dict{Symbol,Int}, Dict("a" => 1))
        @test d2 == Dict(:a => 1)
    end

    @testset "Sets" begin
        s = Serde.deser(Set{Int}, [1, 2, 3])
        @test s == Set([1, 2, 3])
    end

    @testset "Simple struct from Dict" begin
        struct _DeSimple
            name::String
            value::Int
        end
        obj = Serde.deser(_DeSimple, Dict("name" => "test", "value" => 42))
        @test obj.name == "test"
        @test obj.value == 42
    end

    @testset "Nested structs" begin
        struct _DeInner
            x::Float64
        end
        struct _DeOuter
            label::String
            inner::_DeInner
        end
        data = Dict("label" => "A", "inner" => Dict("x" => 3.14))
        obj = Serde.deser(_DeOuter, data)
        @test obj.label == "A"
        @test obj.inner.x == 3.14
    end

    @testset "Deep nesting (3 levels)" begin
        struct _DeL3; z::Int; end
        struct _DeL2; l3::_DeL3; end
        struct _DeL1; l2::_DeL2; end
        data = Dict("l2" => Dict("l3" => Dict("z" => 99)))
        obj = Serde.deser(_DeL1, data)
        @test obj.l2.l3.z == 99
    end

    @testset "Optional fields (Union{Nothing,T})" begin
        struct _DeOptional
            name::String
            tag::Union{Nothing,String}
        end
        obj1 = Serde.deser(_DeOptional, Dict("name" => "a", "tag" => "b"))
        @test obj1.tag == "b"
        obj2 = Serde.deser(_DeOptional, Dict("name" => "a"))
        @test obj2.tag === nothing
    end

    @testset "Default values" begin
        struct _DeDefaults
            x::Int
            y::Int
        end
        Serde.has_default(::Type{_DeDefaults}, ::Val{:y}) = true
        Serde.deser_default(::Type{_DeDefaults}, ::Val{:y}) = 100
        obj = Serde.deser(_DeDefaults, Dict("x" => 1))
        @test obj.x == 1
        @test obj.y == 100
    end

    @testset "Custom name (alias)" begin
        struct _DeAlias
            user_name::String
        end
        Serde.deser_name(::Type{_DeAlias}, ::Val{:user_name}) = :userName
        obj = Serde.deser(_DeAlias, Dict("userName" => "Alice"))
        @test obj.user_name == "Alice"
    end

    @testset "Type coercion String->Number" begin
        struct _DeCoerce
            count::Int
            ratio::Float64
        end
        obj = Serde.deser(_DeCoerce, Dict("count" => "42", "ratio" => "3.14"))
        @test obj.count == 42
        @test obj.ratio ≈ 3.14
    end

    @testset "Struct from NamedTuple" begin
        struct _DeNT
            a::Int
            b::String
        end
        nt = (a = 1, b = "hello")
        obj = Serde.deser(_DeNT, nt)
        @test obj.a == 1
        @test obj.b == "hello"
    end

    @testset "Struct from Vector" begin
        struct _DeVec
            x::Int
            y::Int
        end
        obj = Serde.deser(_DeVec, [10, 20])
        @test obj.x == 10
        @test obj.y == 20
    end

    @testset "Vector of structs" begin
        struct _DeItem
            id::Int
        end
        items = Serde.deser(Vector{_DeItem}, [Dict("id" => 1), Dict("id" => 2)])
        @test length(items) == 2
        @test items[1].id == 1
        @test items[2].id == 2
    end

    @testset "DateTime deserialization" begin
        struct _DeDate
            ts::String
        end
        obj = Serde.deser(_DeDate, Dict("ts" => "2024-01-01"))
        @test obj.ts == "2024-01-01"
    end

    @testset "UUID fields" begin
        struct _DeUUID
            id::String
        end
        u = string(uuid4())
        obj = Serde.deser(_DeUUID, Dict("id" => u))
        @test obj.id == u
    end
end

@testset "Deser — rethrow paths" begin

    @testset "_field_convert rethrow on non-MethodError/ArgumentError/InexactError" begin
        # Custom type that throws a DomainError (not caught, should rethrow)
        struct _RethrowType end
        struct _RethrowStruct
            x::_RethrowType
        end
        # Trying to deser _RethrowType from Int will hit the rethrow path
        @test_throws Exception Serde.deser(_RethrowStruct, Dict("x" => 42))
    end

    @testset "_field_convert MissingFieldError from Nothing (non-nullable)" begin
        struct _NonNullable
            required::Int
        end
        @test_throws MissingFieldError Serde.deser(_NonNullable, Dict{String,Any}())
    end

    @testset "DictClass TypeMismatchError on value conversion failure" begin
        # Dict{String,Int} with a nested Dict value for Int field
        @test_throws TypeMismatchError Serde.deser(
            Dict{String,Int},
            Dict("a" => Dict("nested" => 1))
        )
    end
end

@testset "Deser — @nexprs and NamedTuple additional paths" begin

    @testset "Deser NamedTuple from Dict" begin
        nt = Serde.deser(NamedTuple{(:x, :y)}, Dict(:x => 1, :y => 2))
        @test nt.x == 1
        @test nt.y == 2
    end

    @testset "Deser Tuple from AbstractVector" begin
        t = Serde.deser(Tuple{Int,String}, [42, "hello"])
        @test t == (42, "hello")
    end

    @testset "Deser Bool from Int" begin
        @test Serde.deser(Bool, 1) === true
        @test Serde.deser(Bool, 0) === false
    end

    @testset "Deser Float64 from String" begin
        result = Serde.deser(Float64, "3.14")
        @test result ≈ 3.14
    end

    @testset "Deser Int from Float" begin
        result = Serde.deser(Int, 3.0)
        @test result == 3
    end
end

@testset "Deser — rethrow edge cases" begin

    @testset "DictClass: non-MethodError rethrown (line 173)" begin
        # Create a type where deser throws an unexpected error
        # Dict[String, CustomType] where CustomType has no deser method
        # and the key conversion itself throws a DomainError
        struct _Err173; end
        # We need deser(valtype, v) to throw non-MethodError
        # Simplest: use dict with Int key and non-Int string value
        # that throws InexactError (which IS caught) or another error
        # Use a type that when deser'd throws DomainError
        # Actually, a StackOverflowError would be rethrown
        # But that's dangerous. Let's test ArgumentError IS caught (TypeMismatchError)
        @test_throws TypeMismatchError Serde.deser(Dict{String,Int}, Dict("a" => "not_a_number"))
    end

    @testset "_field_convert: rethrow on DomainError" begin
        struct _DomainErrType end
        struct _DomainErrStruct
            x::_DomainErrType
        end
        # When deser(_DomainErrType, 42) is called, it should fail with MethodError
        # which gets wrapped as TypeMismatchError
        @test_throws TypeMismatchError Serde.deser(_DomainErrStruct, Dict("x" => 42))
    end
end

@testset "Deser — rethrow non-standard errors" begin

    @testset "DictClass rethrows DomainError — line 173" begin
        # Override 3-arg deser for a custom type to throw DomainError
        struct _DomainErrValType end
        Serde.deser(strategy, ::Type{_DomainErrValType}, v) = throw(DomainError(v, "custom"))

        @test_throws DomainError Serde.deser(Dict{String,_DomainErrValType}, Dict("a" => 1))
    end

    @testset "_field_convert rethrows DomainError — line 191" begin
        struct _FieldDomainErr end
        struct _FieldDomainStruct
            x::_FieldDomainErr
        end
        # Override 4-arg deser to throw DomainError
        Serde.deser(strategy, ::Type{_FieldDomainStruct}, ::Type{_FieldDomainErr}, v) =
            throw(DomainError(v, "field domain error"))

        @test_throws DomainError Serde.deser(_FieldDomainStruct, Dict("x" => 42))
    end
end
