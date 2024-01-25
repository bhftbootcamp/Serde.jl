# Utl/Utl

@testset verbose = true "Utl" begin
    @testset "Case №1: Nested dictionary" begin
        nested_dict = Dict(:value => 1, :sub => Dict(:value => 2, :sub => Dict(:value => 3)))

        @test to_flatten(nested_dict) == Dict{String,Int64}(
            "value" => 1,
            "sub_value" => 2,
            "sub_sub_value" => 3,
        )

        @test to_flatten(nested_dict; delim = "") == Dict{String,Int64}(
            "value" => 1,
            "subvalue" => 2,
            "subsubvalue" => 3,
        )

        nested_dict = Dict(:a => Dict(:b => 1, :c => 2), :b => Dict(:d => 3, :e => 4))

        @test to_flatten(nested_dict) == Dict{String,Int64}(
            "a_b" => 1,
            "a_c" => 2,
            "b_d" => 3,
            "b_e" => 4,
        )
    end

    @testset "Case №2: Nested type" begin
        struct Nested
            value::Int64
            sub::Union{Nothing,Nested}
        end

        nested_type = Nested(1, Nested(2, Nested(3, nothing)))

        @test to_flatten(nested_type) == Dict{String,Int64}(
            "value" => 1,
            "sub_value" => 2,
            "sub_sub_value" => 3,
        )

        @test to_flatten(nested_type; delim = "") == Dict{String,Int64}(
            "value" => 1,
            "subvalue" => 2,
            "subsubvalue" => 3,
        )
    end
end
