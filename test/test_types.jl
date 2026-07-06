@testset "ClassType dispatch" begin
    @test Serde.ClassType(Int) === Serde.PrimitiveClass()
    @test Serde.ClassType(Float64) === Serde.PrimitiveClass()
    @test Serde.ClassType(String) === Serde.PrimitiveClass()
    @test Serde.ClassType(Symbol) === Serde.PrimitiveClass()
    @test Serde.ClassType(Char) === Serde.PrimitiveClass()
    @test Serde.ClassType(Bool) === Serde.PrimitiveClass()
    @test Serde.ClassType(Dates.DateTime) === Serde.PrimitiveClass()
    @test Serde.ClassType(Dates.Date) === Serde.PrimitiveClass()
    @test Serde.ClassType(UUID) === Serde.PrimitiveClass()

    @test Serde.ClassType(Nothing) === Serde.NullClass()
    @test Serde.ClassType(Missing) === Serde.NullClass()

    @test Serde.ClassType(Vector{Int}) === Serde.VectorClass()
    @test Serde.ClassType(Tuple{Int,String}) === Serde.VectorClass()
    @test Serde.ClassType(Set{Int}) === Serde.VectorClass()

    @test Serde.ClassType(Dict{String,Any}) === Serde.DictClass()
    @test Serde.ClassType(Pair{String,Int}) === Serde.DictClass()

    @test Serde.ClassType(NamedTuple{(:a,),Tuple{Int}}) === Serde.NTupleClass()

    @test Serde.ClassType(Union{Nothing,Int}) === Serde.UnionClass()
    @test Serde.ClassType(Union{Missing,String}) === Serde.UnionClass()

    struct _TypeTestStruct; x::Int; end
    @test Serde.ClassType(_TypeTestStruct) === Serde.StructClass()

    @test_throws ArgumentError Serde.ClassType(typeof(println))
end

@testset "Error types" begin
    @testset "ParseError" begin
        inner = ErrorException("bad input")
        e = ParseError("JSON", "invalid syntax", inner)
        buf = IOBuffer()
        showerror(buf, e)
        msg = String(take!(buf))
        @test contains(msg, "ParseError")
        @test contains(msg, "JSON")
    end

    @testset "MissingFieldError" begin
        e = MissingFieldError(Dict, :host)
        buf = IOBuffer()
        showerror(buf, e)
        msg = String(take!(buf))
        @test contains(msg, "host")
        @test contains(msg, "MissingFieldError")
        @test contains(msg, "Dict")
    end

    @testset "TypeMismatchError" begin
        e = TypeMismatchError(Dict, :port, Int, String, "abc")
        buf = IOBuffer()
        showerror(buf, e)
        msg = String(take!(buf))
        @test contains(msg, "TypeMismatchError")
        @test contains(msg, "field 'port'")
        @test contains(msg, "Dict")
        @test contains(msg, "Int")
        @test contains(msg, "String")
        @test e isa DeserError
        @test e isa SerdeError
    end

    @testset "ValidationError" begin
        e = ValidationError(Dict, :email, "invalid", "must contain @")
        buf = IOBuffer()
        showerror(buf, e)
        msg = String(take!(buf))
        @test contains(msg, "ValidationError")
        @test contains(msg, "email")
        @test contains(msg, "invalid")
        @test contains(msg, "must contain @")
    end
end
