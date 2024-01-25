# Ser/SerCsv

@testset verbose = true "SerCsv" begin
    @testset "Case №1: Simple" begin
        struct CsvFoo1
            a::Int64
            b::String
            c::Int64
            d::Union{String,Float64}
        end

        foo1 = [
            CsvFoo1(1, "a", 11, 11.1),
            CsvFoo1(2, "b", 22, "bb"),
            CsvFoo1(2, "b", 22, "bb"),
        ]

        csv = """
        a,b,c,d
        1,a,11,11.1
        2,b,22,bb
        2,b,22,bb
        """

        @test Serde.to_csv(foo1) |> strip == csv |> strip
    end

    @testset "Case №2: Normalize" begin
        struct CsvBoo2
            g::String
        end

        struct CsvBar2
            e::Int64
            f::CsvBoo2
        end

        struct CsvFoo2
            a::Int64
            b::String
            c::Int64
            d::Union{String,Float64,CsvBar2}
        end

        foo2 = [
            CsvFoo2(1, "Hello", 3, "World"),                                   # String in d field
            CsvFoo2(2, "Julia", 5, 3.14),                                      # Float64 in d field
            CsvFoo2(3, "Coconut", 7, CsvBar2(42, CsvBoo2("Nested object"))),   # CsvBar2 in d field
        ]

        csv = """
        a,b,c,d,d_e,d_f_g
        1,Hello,3,World,,
        2,Julia,5,3.14,,
        3,Coconut,7,,42,Nested object
        """

        @test Serde.to_csv(foo2) |> strip == csv |> strip
    end

    @testset "Case №3: Wrap Value" begin
        struct CsvFoo6
            a::Int64
            b::String
            c::Int64
            d::Union{String,Float64}
        end

        foo3 = [
            CsvFoo6(1, "a,,,,;", 11, 11.1),
            CsvFoo6(2, "b\nl", 22, "bb\"\""),
            CsvFoo6(1, "a,,,,;", 12, 11.1),
        ]

        csv = """
        a,b,c,d
        1,"a,,,,;",11,11.1
        2,"b
        l",22,"bb\"\"\"\""
        1,"a,,,,;",12,11.1
        """

        @test Serde.to_csv(foo3) |> strip == csv |> strip
    end

    @testset "Case №4: Dict" begin
        foo_dict = [
            IdDict("a" => 10, "B" => 20),
            Dict("a" => 15, "B" => 32),
            WeakKeyDict("a" => 10, "B" => 35),
        ]

        csv = """
        B;a
        20;10
        32;15
        35;10
        """

        @test Serde.to_csv(foo_dict, separator = ";") |> strip == csv |> strip

        foo_dict = [
            Dict("a" => 10, "B" => 20, "C" => Dict("cfoo" => "foo", "cbaz" => "baz")),
            Dict(:a => 10, :B => 20),
        ]

        csv = """
        a,B,C_cbaz,C_cfoo
        10,20,baz,foo
        10,20,,
        """

        @test Serde.to_csv(foo_dict, headers = ["a", "B", "C_cbaz", "C_cfoo"]) |> strip == csv |> strip
    end
end
