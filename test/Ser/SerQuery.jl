# Ser/SerQuery

abstract type Comparable end

import Base.==

function ==(a::T, b::T) where {T<:Comparable}
    f = fieldnames(T)
    return getfield.(Ref(a), f) == getfield.(Ref(b), f)
end

@testset verbose = true "SerQuery" begin
    @testset "Case №1: SerQuery" begin
        struct QueryFoo1 <: Comparable
            foo::String
            bar::Int
            baz::Vector{String}
        end

        exp_str = "foo=hello%20world&bar=42&baz=%5Ba%2Cb%2Cc%5D"
        exp_obj = QueryFoo1("hello world", 42, ["a", "b", "c"])

        sered = Serde.to_query(exp_obj)
        @test sered == exp_str

        desered = Serde.deser_query(QueryFoo1, sered)
        @test desered == exp_obj

        exp_str = "foo=&bar=0&baz=[]"
        exp_obj = QueryFoo1("", 0, [])

        sered = Serde.to_query(exp_obj; escape = false)
        @test sered == exp_str

        desered = Serde.deser_query(QueryFoo1, sered)
        @test desered == exp_obj

        exp_str = "foo=escapeme%26&bar=123&baz=%5Bescape%2Bme%2Cescapeme%5D"
        exp_obj = QueryFoo1("escapeme&", 123, ["escape+me", "escapeme"])

        sered = Serde.to_query(exp_obj)
        @test sered == exp_str

        desered = Serde.deser_query(QueryFoo1, sered)
        @test desered == exp_obj

        exp_str = "foo=unicode&bar=42&baz=%5B%F0%9F%99%82%2C%F0%9F%91%8D%5D"
        exp_obj = QueryFoo1("unicode", 42, ["🙂", "👍"])

        sered = Serde.to_query(exp_obj)
        @test sered == exp_str

        desered = Serde.deser_query(QueryFoo1, sered)
        @test desered == exp_obj

        exp_str = "bar=42Abaz=%5Ba%2Cb%2Cc%5DAfoo=hello%20world"
        exp_obj = Dict("foo" => "hello world", "bar" => 42, "baz" => ["a", "b", "c"])
        @test Serde.to_query(exp_obj; delimiter = "A") == exp_str

        exp_str = "bar=42&baz=%5Ba%2Cb%2Cc%5D&foo=hello%20world"
        exp_obj = Dict("foo" => "hello world", "bar" => 42, "baz" => ["a", "b", "c"])
        @test Serde.to_query(exp_obj; sort_keys = true) == exp_str

        exp_str = "bar=42&baz=[a,b,c]&foo=hello world"
        exp_obj = Dict("foo" => "hello world", "bar" => 42, "baz" => ["a", "b", "c"])
        @test Serde.to_query(exp_obj; escape = false) == exp_str

        exp_obj = Dict("@A123" => "")
        exp_str = "%40A123="
        @test Serde.to_query(exp_obj) == exp_str

        exp_obj = Dict("q" => """\u4F60\u597D""")
        exp_str = "q=%E4%BD%A0%E5%A5%BD"
        @test Serde.to_query(exp_obj) == exp_str

        exp_obj = Dict("q" => """\ud800\ud800""")
        exp_str = "q=%ED%A0%80%ED%A0%80"
        @test Serde.to_query(exp_obj) == exp_str

        exp_obj = Dict("q" => "<asdf>")
        exp_str = "q=%3Casdf%3E"
        @test Serde.to_query(exp_obj) == exp_str

        exp_obj = Dict("q" => "\"asdf\"")
        exp_str = "q=%22asdf%22"
        @test Serde.to_query(exp_obj) == exp_str

        exp_obj = Dict("   foo   " => ["   bar     "])
        exp_str = "%20%20%20foo%20%20%20=%5B%20%20%20bar%20%20%20%20%20%5D"
        @test Serde.to_query(exp_obj) == exp_str

        exp_obj = Dict("foo" => ["ａ"])
        exp_str = "foo=%5B%EF%BD%81%5D"
        @test Serde.to_query(exp_obj) == exp_str

        exp_obj = Dict("foo" => ["""\xa1\xc1"""])
        exp_str = "foo=%5B%A1%C1%5D"
        @test Serde.to_query(exp_obj) == exp_str

        exp_obj = Dict("foo" => ["???"])
        exp_str = "foo=%5B%3F%3F%3F%5D"
        @test Serde.to_query(exp_obj) == exp_str

        exp_obj = Dict("D\xfcrst" => "")
        exp_str = "D%FCrst="
        @test Serde.to_query(exp_obj) == exp_str
    end

    @testset "Case №2: All basic types" begin
        struct QueryFoo2 <: Comparable
            string::String
            int::Int64
            float::Float64
            bool::Bool
            miss::Missing
            noth::Nothing
            symbol::Symbol
        end

        exp_str = "string=str&int=42&float=24.6&bool=true&symbol=symb"
        exp_obj = QueryFoo2("str", 42, 24.6, true, missing, nothing, :symb)
        @test Serde.to_query(exp_obj) == exp_str
    end

    @testset "Case №3: Ignore null" begin
        abstract type AbstractQuery_3 <: Comparable end

        (Serde.SerQuery.ser_ignore_null(::Type{A})::Bool) where {A<:AbstractQuery_3} = true

        Base.@kwdef struct QueryFoo3_1 <: AbstractQuery_3
            x::String
            b::Union{String,Nothing} = nothing
        end

        exp_str = "x=test"
        exp_obj = QueryFoo3_1("test", nothing)

        sered = Serde.to_query(exp_obj)
        @test sered == exp_str

        desered = Serde.deser_query(QueryFoo3_1, sered)
        @test desered == exp_obj

        Base.@kwdef struct QueryFoo3_2 <: AbstractQuery_3
            x::String
            b::Union{String,Nothing} = nothing
            c::Union{Int64,Nothing} = nothing
        end

        exp_str = "x=test&c=100"
        exp_obj = QueryFoo3_2("test", nothing, 100)

        sered = Serde.to_query(exp_obj)
        @test sered == exp_str

        desered = Serde.deser_query(QueryFoo3_2, sered)
        @test desered == exp_obj
    end

    @testset "Case №4: Сustom type" begin
        struct QueryFoo4
            dt::DateTime
        end

        Serde.SerQuery.ser_type(::Type{QueryFoo4}, x::DateTime) = string(datetime2unix(x))

        exp_str = "dt=1.677538897248e9"
        exp_obj = QueryFoo4(DateTime("2023-02-27T23:01:37.248"))

        @test Serde.to_query(exp_obj) === exp_str
    end
end
