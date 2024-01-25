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

        q = QueryFoo1("hello world", 42, ["a", "b", "c"])
        expected = "foo=hello%20world&bar=42&baz=%5Ba%2Cb%2Cc%5D"
        sered = Serde.to_query(q)
        desered = Serde.deser_query(QueryFoo1, sered)
        @test sered == expected && desered == q

        q = QueryFoo1("", 0, [])
        expected = "foo=&bar=0&baz=[]"
        sered = Serde.to_query(q; escape = false)
        desered = Serde.deser_query(QueryFoo1, sered)
        @test sered == expected && desered == q

        q = QueryFoo1("escapeme&", 123, ["escape+me", "escapeme"])
        expected = "foo=escapeme%26&bar=123&baz=%5Bescape%2Bme%2Cescapeme%5D"
        sered = Serde.to_query(q)
        desered = Serde.deser_query(QueryFoo1, sered)
        @test sered == expected && desered == q

        q = QueryFoo1("unicode", 42, ["🙂", "👍"])
        expected = "foo=unicode&bar=42&baz=%5B%F0%9F%99%82%2C%F0%9F%91%8D%5D"
        sered = Serde.to_query(q)
        desered = Serde.deser_query(QueryFoo1, sered)
        @test sered == expected && desered == q
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

        q = QueryFoo2("str", 42, 24.6, true, missing, nothing, :symb)
        expected = "string=str&int=42&float=24.6&bool=true&symbol=symb"
        sered = Serde.to_query(q)
        @test sered == expected
    end

    @testset "Case №3: Ignore null" begin
        abstract type AbstractQuery_3 <: Comparable end

        Base.@kwdef struct QueryFoo3_1 <: AbstractQuery_3
            x::String
            b::Union{String,Nothing} = nothing
        end

        Base.@kwdef struct QueryFoo3_2 <: AbstractQuery_3
            x::String
            b::Union{String,Nothing} = nothing
            c::Union{Int64,Nothing} = nothing
        end

        (Serde.SerQuery.ignore_null(::Type{A})::Bool) where {A<:AbstractQuery_3} = true

        foo1 = QueryFoo3_1(x = "test")
        foo2 = QueryFoo3_2(x = "test", c = 100)

        expected1 = "x=test"
        expected2 = "x=test&c=100"
        sered1 = Serde.to_query(foo1)
        sered2 = Serde.to_query(foo2)
        @test expected1 == sered1 && Serde.deser_query(QueryFoo3_1, sered1) == foo1
        @test expected2 == sered2 && Serde.deser_query(QueryFoo3_2, sered2) == foo2
    end

    @testset "Case №4: Сustom type" begin
        struct QueryFoo4
            dt::DateTime
        end

        Serde.SerQuery.ser_type(::Type{QueryFoo4}, x::DateTime) = string(datetime2unix(x))

        @test Serde.to_query(QueryFoo4(DateTime("2023-02-27T23:01:37.248"))) === "dt=1.677538897248e9"
    end
end