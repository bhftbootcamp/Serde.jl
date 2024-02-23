# Ser/SerXml

@testset verbose = true "SerXml" begin
    @testset "Case №1: SerXml" begin
        struct BarXml1
            str::String
            symb::Symbol
            char::Char
            type::DataType
            num::Float64
            _::String
        end

        struct FooXml1
            date::Date
            bar::BarXml1
        end

        exp_obj = FooXml1(Date("2023-07-30"), BarXml1("text", :ok, 'g', Int64, 3.14, "CONTENT"))
        exp_str = """
        <xml date="2023-07-30">
          <bar str="text" symb="ok" char="g" type="Int64" num="3.14">CONTENT</bar>
        </xml>
        """
        @test Serde.SerXml.to_xml(exp_obj) == exp_str

        exp_obj = FooXml1(Date("2023-07-30"), BarXml1("text", :ok, 'g', Int64, 3.14, "CONTENT"))
        exp_str = """
        <dexamel date="2023-07-30">
          <bar str="text" symb="ok" char="g" type="Int64" num="3.14">CONTENT</bar>
        </dexamel>
        """
        @test Serde.SerXml.to_xml(exp_obj; key = "dexamel") == exp_str
    end

    @testset "Case №2: XmlVector" begin
        exp_obj =
            Dict("vector_elems" => [Dict("_" => 1), Dict("_" => "text"), Dict("Name" => Dict("_" => "Ivan"))])

        exp_str = """
        <xml>
          <vector_elems>1</vector_elems>
          <vector_elems>text</vector_elems>
          <vector_elems>
            <Name>Ivan</Name>
          </vector_elems>
        </xml>
        """

        @test Serde.SerXml.to_xml(exp_obj) == exp_str
    end

    @testset "Case №3: SerXml" begin
        exp_obj = Dict(
            "Node1" => Dict("_" => "text"),
            "Node2" => Dict("_" => "bottom text"),
            "attribute1" => 12,
            "attribute2" => "str",
        )

        exp_str = """
        <xml attribute2="str" attribute1="12">
          <Node2>bottom text</Node2>
          <Node1>text</Node1>
        </xml>
        """

        @test Serde.SerXml.to_xml(exp_obj) == exp_str
    end

    @testset "Case №4: EmptyTag" begin
        struct BarXml4
            str::String
        end

        struct FooXml4
            bar::BarXml4
        end

        exp_obj = FooXml4(BarXml4("bottom text"))
        exp_str = """
        <xml>
          <bar str="bottom text"/>
        </xml>
        """
        @test Serde.SerXml.to_xml(exp_obj) == exp_str

        exp_obj = Dict("bar" => Dict("_" => "bottom text"))
        exp_str = """
        <xml>
          <bar>bottom text</bar>
        </xml>
        """
        @test Serde.SerXml.to_xml(exp_obj) == exp_str
    end

    @testset "Case №5: Content" begin
        struct BarXml5
            _::String
        end

        struct FooXml5
            bar::BarXml5
        end

        exp_obj = FooXml5(BarXml5("CONTENT"))
        exp_str = """
        <xml>
          <bar>CONTENT</bar>
        </xml>
        """
        @test Serde.SerXml.to_xml(exp_obj) == exp_str

        exp_obj = Dict("bar" => Dict("_" => "CONTENT"))
        exp_str = """
        <xml>
          <bar>CONTENT</bar>
        </xml>
        """
        @test Serde.SerXml.to_xml(exp_obj) == exp_str
    end

    @testset "Case №6: Vector again" begin
        exp_obj = Dict(
            "c" => Dict("_" => "20"),
            "a" => Any[
                "30",
                Dict("b" => "40", "a" => "10"),
                Dict("b" => "40", "a" => "10"),
                Dict("b" => "40", "a" => "10"),
                Dict("b" => "40", "a" => "10"),
            ],
        )
        exp_str = """
        <xml>
          <c>20</c>
          <a>30</a>
          <a b="40" a="10"/>
          <a b="40" a="10"/>
          <a b="40" a="10"/>
          <a b="40" a="10"/>
        </xml>
        """
        @test Serde.SerXml.to_xml(exp_obj) == exp_str
    end
end
