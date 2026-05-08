@testset "Query format" begin
    @testset "parse_query basic" begin
        d = parse_query("key=value&num=42")
        @test d["key"] == "value"
        @test d["num"] == "42"
    end

    @testset "parse_query with encoding" begin
        d = parse_query("name=hello%20world")
        @test d["name"] == "hello world"
    end

    @testset "parse_query Vector fields via from_query" begin
        struct _QueryBB
            vector::Vector{String}
            value::String
        end
        obj = from_query(_QueryBB, "value=abc&vector=[1,2,3]")
        @test obj.value == "abc"
        @test obj.vector == ["1", "2", "3"]
    end

    @testset "parse_query Vector{UInt8}" begin
        bytes = Vector{UInt8}("a=1&b=2")
        d = parse_query(bytes)
        @test d["a"] == "1"
    end

    @testset "from_query basic" begin
        struct _QueryBasic
            age::Int
            name::String
        end
        obj = from_query(_QueryBasic, "age=20&name=Nancy")
        @test obj.age == 20
        @test obj.name == "Nancy"
    end

    @testset "from_query with vectors" begin
        struct _QueryVec
            items::Vector{String}
            value::String
        end
        obj = from_query(_QueryVec, "value=abc&items=[1,2,3]")
        @test obj.value == "abc"
        @test length(obj.items) == 3
    end

    @testset "to_query basic" begin
        struct _QuerySer
            int_val::Int
            float_val::Float64
        end
        q = to_query(_QuerySer(1, 2.0))
        @test contains(q, "int_val=1")
        @test contains(q, "float_val=2.0")
        @test contains(q, "&")
    end

    @testset "to_query with vectors" begin
        struct _QuerySerVec
            items::Vector{String}
        end
        q = to_query(_QuerySerVec(["a", "b"]); escape = false)
        @test contains(q, "items=[a,b]")
    end

    @testset "to_query escape" begin
        q = to_query(Dict("key" => "hello world"))
        @test contains(q, "hello%20world")
    end

    @testset "to_query sort_keys" begin
        struct _QuerySort
            b::Int
            a::Int
        end
        q = to_query(_QuerySort(2, 1); sort_keys = true)
        a_pos = findfirst("a=", q)
        b_pos = findfirst("b=", q)
        @test a_pos !== nothing
        @test b_pos !== nothing
        @test first(a_pos) < first(b_pos)
    end

    @testset "to_query no escape" begin
        q = to_query(Dict("key" => "a b"); escape = false)
        @test q == "key=a b"
    end

    @testset "to_query custom delimiter" begin
        q = to_query(Dict("a" => "1", "b" => "2"); delimiter = ";", escape = false)
        @test contains(q, ";")
    end

    @testset "Round-trip" begin
        struct _QueryRound
            name::String
            age::Int
        end
        original = _QueryRound("Alice", 30)
        q = to_query(original; escape = false)
        recovered = from_query(_QueryRound, q)
        @test recovered.name == original.name
        @test recovered.age == original.age
    end
end

@testset "Query — remaining coverage paths" begin

    @testset "try_from_query strategy — error as SerdeError" begin
        struct _QCtxBad; x::Int; end
        result = try_from_query(CamelCase(), _QCtxBad, "y=abc")
        @test result isa SerdeError
    end

    @testset "parse_query + with no '=' sign — empty value" begin
        d = parse_query("empty&val=1")
        @test d["val"] == "1"
        @test d["empty"] == ""
    end

    @testset "_query_cut returns (s, empty) for no separator" begin
        # parse_query("key") returns key with value ""
        d = parse_query("justkey")
        @test haskey(d, "justkey")
    end
end

@testset "Query — ParseError rethrow for non-SerdeError (line 121)" begin

    @testset "dict_type that fails on assignment triggers ParseError — line 121" begin
        # Using Dict{String,String} causes a MethodError when trying to assign
        # a Vector{String} value (from collecting multiple values for same key),
        # which is not a SerdeError, so line 121 executes.
        # But actually single-value case assigns the string directly, so we need
        # a type mismatch: use Dict{String,Int} — _query_unescape returns String,
        # trying to store String as Int throws MethodError (non-SerdeError)
        @test_throws ParseError parse_query("key=value"; dict_type = Dict{String,Int})
    end
end
