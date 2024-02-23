# Utl/Utl

@testset verbose = true "Utl" begin
    @testset "Case №1: Nested dictionary" begin
        exp_kvs = Dict(:value => 1, :sub => Dict(:value => 2, :sub => Dict(:value => 3)))
        exp_obj = Dict{String,Int64}("value" => 1, "sub_value" => 2, "sub_sub_value" => 3)
        @test to_flatten(exp_kvs) == exp_obj

        exp_kvs = Dict(:value => 1, :sub => Dict(:value => 2, :sub => Dict(:value => 3)))
        exp_obj = Dict{String,Int64}("value" => 1, "subvalue" => 2, "subsubvalue" => 3)
        @test to_flatten(exp_kvs; delimiter = "") == exp_obj

        exp_kvs = Dict(:a => Dict(:b => 1, :c => 2), :b => Dict(:d => 3, :e => 4))
        exp_obj = Dict{String,Int64}("a_b" => 1, "a_c" => 2, "b_d" => 3, "b_e" => 4)
        @test to_flatten(exp_kvs) == exp_obj
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
