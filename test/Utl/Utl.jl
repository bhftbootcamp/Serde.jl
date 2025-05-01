# Utl/Utl

@testset verbose = true "Utl" begin
    @testset "Case №1: Nested dictionary" begin
        data = Dict(:value => 1, :sub => Dict(:value => 2, :sub => Dict(:value => 3)))

        exp_obj = Dict("value" => 1, "sub_value" => 2, "sub_sub_value" => 3)
        @test to_flatten(data) == exp_obj
        @test to_flatten(Dict{String, Int}, data) == exp_obj
        @test to_flatten(Dict{String, Int}, data) isa Dict{String, Int}

        exp_obj = Dict("value" => 1, "subvalue" => 2, "subsubvalue" => 3)
        @test to_flatten(data; delimiter = "") == exp_obj
        @test to_flatten(Dict{String, Int}, data; delimiter="") == exp_obj
        @test to_flatten(Dict{String, Int}, data; delimiter="") isa Dict{String, Int}

        data = Dict(:a => Dict(:b => 1, :c => 2), :b => Dict(:d => 3, :e => 4))
        exp_obj = Dict("a_b" => 1, "a_c" => 2, "b_d" => 3, "b_e" => 4)
        @test to_flatten(data) == exp_obj
    end

    @testset "Case №2: Nested type" begin
        struct Nested
            value::Int64
            sub::Union{Nothing,Nested}
        end

        exp_kvs = Dict{String,Int64}("value" => 1, "sub_value" => 2, "sub_sub_value" => 3)
        exp_obj = Nested(1, Nested(2, Nested(3, nothing)))
        @test to_flatten(exp_obj) == exp_kvs

        exp_kvs = Dict{String,Int64}("value" => 1, "subvalue" => 2, "subsubvalue" => 3)
        exp_obj = Nested(1, Nested(2, Nested(3, nothing)))
        @test to_flatten(exp_obj; delimiter = "") == exp_kvs
    end
end
