@testset "Serde.iter_fields helper" begin
    struct _IF; user_id::Int; full_name::String; secret::String; end
    Serde.ser_skip(::Type{_IF}, ::Val{:secret}) = true

    # Without a strategy — applies skip + ser_name + ser_value pipeline.
    out = Tuple{Symbol,Any}[]
    Serde.iter_fields(_IF(1, "Ada", "hush")) do k, v
        push!(out, (k, v))
    end
    @test out == [(:user_id, 1), (:full_name, "Ada")]

    # With a strategy — the chain semantic in `With` flows through.
    out2 = Tuple{Symbol,Any}[]
    Serde.iter_fields(CamelCase(), _IF(1, "Ada", "hush")) do k, v
        push!(out2, (k, v))
    end
    @test out2 == [(:userId, 1), (:fullName, "Ada")]

    # Zero-field structs invoke the callback zero times.
    struct _IFE end
    called = Ref(0)
    Serde.iter_fields(_IFE()) do _, _
        called[] += 1
    end
    @test called[] == 0

    # Non-struct values (Dict, Vector, primitives) are rejected so we never
    # accidentally expose internal type fields (`slots`, `keys`, `vals`, …).
    @test_throws ArgumentError Serde.iter_fields(Dict("a"=>1)) do _,_ end
    @test_throws ArgumentError Serde.iter_fields([1,2,3]) do _,_ end
    @test_throws ArgumentError Serde.iter_fields("hi") do _,_ end
    @test_throws ArgumentError Serde.iter_fields(42) do _,_ end

    # NamedTuples are accepted (NTupleClass).
    nt_out = Tuple{Symbol,Any}[]
    Serde.iter_fields((a=1, b="x")) do k, v
        push!(nt_out, (k, v))
    end
    @test nt_out == [(:a, 1), (:b, "x")]

    # >32 fields — the slow-path fallback runs without dropping any.
    fields_src = join(["f$i::Int" for i in 1:35], "; ")
    eval(Meta.parse("struct _IF35; $fields_src; end"))
    eval(Meta.parse("_if35 = _IF35($(join(1:35, ", ")))"))
    out35 = Tuple{Symbol,Any}[]
    Serde.iter_fields(_if35) do k, v
        push!(out35, (k, v))
    end
    @test length(out35) == 35
    @test out35[33] == (:f33, 33)
    @test out35[end] == (:f35, 35)
end

@testset "Ser engine" begin
    @testset "ser_pairs basic" begin
        struct _SerBasic
            name::String
            value::Int
        end
        pairs = Serde.ser_pairs(_SerBasic("test", 42))
        @test length(pairs) == 2
        @test pairs[1] == (:name, "test")
        @test pairs[2] == (:value, 42)
    end

    @testset "ser_pairs with skip" begin
        struct _SerSkip
            visible::String
            hidden::String
        end
        Serde.ser_skip(::Type{_SerSkip}, ::Val{:hidden}) = true
        pairs = Serde.ser_pairs(_SerSkip("a", "b"))
        @test length(pairs) == 1
        @test pairs[1] == (:visible, "a")
    end

    @testset "ser_pairs with rename" begin
        struct _SerRename
            user_name::String
        end
        Serde.ser_name(::Type{_SerRename}, ::Val{:user_name}) = :userName
        pairs = Serde.ser_pairs(_SerRename("Alice"))
        @test pairs[1][1] === :userName
    end

    @testset "ser_pairs with value transform" begin
        struct _SerTransform
            score::Float64
        end
        Serde.ser_value(::Type{_SerTransform}, ::Val{:score}, v) = round(Int, v)
        pairs = Serde.ser_pairs(_SerTransform(3.7))
        @test pairs[1][2] === 4
    end

    @testset "ser_pairs with skip_if (value-based)" begin
        struct _SerSkipIf
            name::String
            age::Int
        end
        Serde.ser_skip(::Type{_SerSkipIf}, ::Val{:age}, v) = v <= 0
        pairs1 = Serde.ser_pairs(_SerSkipIf("A", 25))
        @test length(pairs1) == 2
        pairs2 = Serde.ser_pairs(_SerSkipIf("B", 0))
        @test length(pairs2) == 1
    end

    @testset "isnull" begin
        @test Serde.isnull(nothing) === true
        @test Serde.isnull(missing) === true
        @test Serde.isnull(0) === false
        @test Serde.isnull("") === false
        @test Serde.isnull(false) === false
    end

    @testset "issimple" begin
        @test Serde.issimple("hello") === true
        @test Serde.issimple(:sym) === true
        @test Serde.issimple('c') === true
        @test Serde.issimple(42) === true
        @test Serde.issimple(3.14) === true
        @test Serde.issimple(true) === true
        @test Serde.issimple(Int) === true
        @test Serde.issimple(now()) === true
        @test Serde.issimple([1, 2]) === false
        @test Serde.issimple(Dict()) === false
    end

    @testset "to_flatten" begin
        nested = Dict("a" => 1, "b" => Dict("c" => 2, "d" => Dict("e" => 3)))
        flat = to_flatten(nested)
        @test flat["a"] == 1
        @test flat["b_c"] == 2
        @test flat["b_d_e"] == 3

        flat2 = to_flatten(nested; delimiter = ".")
        @test flat2["b.c"] == 2
        @test flat2["b.d.e"] == 3

        struct _FlatInner; val::Float64; end
        struct _FlatOuter; name::String; inner::_FlatInner; end
        fo = _FlatOuter("x", _FlatInner(1.5))
        flat3 = to_flatten(fo)
        @test flat3["name"] == "x"
        @test flat3["inner_val"] == 1.5
    end
end
