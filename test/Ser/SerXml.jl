# Ser/SerXml

using Serde
using Test, Dates

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

        data = Serde.SerXml.to_xml(
            FooXml1(
                Date("2023-07-30"),
                BarXml1("text", :ok, 'g', Int64, 3.14, "CONTENT"),
            )
        )

        res = """
        <xml date="2023-07-30">
          <bar str="text" symb="ok" char="g" type="Int64" num="3.14">
            CONTENT
          </bar>
        </xml>
        """

        @test data == res
    end

    @testset "Case №2: XmlVector" begin
        data = Serde.SerXml.to_xml(
            Dict(
                "vector_elems" => [
                    1,
                    "text",
                    Dict("Name" => "Ivan"),
                ],
            ),
        )

        res = """
        <xml>
          <vector_elems>1</vector_elems>
          <vector_elems>text</vector_elems>
          <vector_elems>
            <Name>Ivan</Name>
          </vector_elems>
        </xml>
        """

        @test data == res
    end

    @testset "Case №3: SerXml" begin
        data = Serde.SerXml.to_xml(
            Dict(
                "Node1" => "text",
                :attribute1 => 12,
                "Node2" => "bottom text",
                :attribute2 => :str,
            ),
        )

        res = """
        <xml attribute1="12" attribute2="str">
          <Node2>bottom text</Node2>
          <Node1>text</Node1>
        </xml>
        """

        @test data == res
    end

    @testset "Case №4: EmptyTag" begin
        struct BarXml4
            str::String
        end

        struct FooXml4
            bar::BarXml4
        end

        data_struct = Serde.SerXml.to_xml(
            FooXml4(
                BarXml4("bottom text"),
            ),
        )

        data_dict = Serde.SerXml.to_xml(
            Dict("bar" => Dict(:str => "bottom text")),
        )

        res = """
        <xml>
          <bar str="bottom text"/>
        </xml>
        """

        @test data_struct == res
        @test data_dict == res
    end

    @testset "Case №5: Content" begin
        struct BarXml5
            _::String
        end

        struct FooXml5
            bar::BarXml5
        end

        data_struct = Serde.SerXml.to_xml(
            FooXml5(
                BarXml5("CONTENT"),
            ),
        )

        data_dict = Serde.SerXml.to_xml(
            Dict("bar" => Dict("" => "CONTENT")),
        )

        res = """
        <xml>
          <bar>
            CONTENT
          </bar>
        </xml>
        """

        @test data_struct == res
        @test data_dict == res
    end

    @testset "Case №6: Vector again" begin
        data = Serde.SerXml.to_xml(
            Dict(
                "a" => [
                    Dict(:a => 10, :b => 40),
                    Dict(:a => 10, :b => 40),
                    Dict(:a => 10, :b => 40),
                    Dict(:a => 10, :b => 40),
                ],
                "c" => 20,
                :a => 30,
                "" => "hello",
            ),
        )

        res = """
        <xml a="30">
          hello
          <c>20</c>
          <a a="10" b="40"/>
          <a a="10" b="40"/>
          <a a="10" b="40"/>
          <a a="10" b="40"/>
        </xml>
        """

        @test data == res
    end
end
