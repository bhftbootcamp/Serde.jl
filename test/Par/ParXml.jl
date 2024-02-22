# Par/ParXml

@testset verbose = true "ParXml" begin
    @testset "Case №1: XML parse" begin
        exp_str = """
        <?xml version="1.0" encoding="UTF-8"?>
        <bookstore>
          <book category="one">
            <title lang="en">Julia for Beginners</title>
            <author>Erik Engheim</author>
            <year>2021</year>
          </book>
          <book category="two">
            <title lang="en">Algorithms for Decision Making</title>
            <author>Mykel J. Kochenderfer</author>
            <author>Tim A. Wheeler</author>
            <author>Kyle H. Wray</author>
            <year>2020</year>
          </book>
        </bookstore>
        """
        exp_obj = Dict(
            "book" => Dict[
                Dict(
                    "author" => Dict("_" => "Erik Engheim"),
                    "year" => Dict("_" => "2021"),
                    "title" => Dict("lang" => "en", "_" => "Julia for Beginners"),
                    "category" => "one",
                ),
                Dict(
                    "author" => Dict[
                        Dict("_" => "Mykel J. Kochenderfer"),
                        Dict("_" => "Tim A. Wheeler"),
                        Dict("_" => "Kyle H. Wray"),
                    ],
                    "year" => Dict("_" => "2020"),
                    "title" => Dict(
                        "lang" => "en",
                        "_" => "Algorithms for Decision Making",
                    ),
                    "category" => "two",
                ),
            ],
        )
        @test Serde.parse_xml(exp_str) == exp_obj
        @test Serde.parse_xml(Vector{UInt8}(exp_str)) == exp_obj
        @test Serde.parse_xml(SubString(exp_str, 1)) == exp_obj
    end

    @testset "Case №2: Escaping tests" begin
        exp_str = """<valid>"'></valid>"""
        exp_obj = Dict("_" => "\"'>")
        @test Serde.parse_xml(exp_str) == exp_obj

        exp_str = """<valid attribute=">"/>"""
        exp_obj = Dict("attribute" => ">")
        @test Serde.parse_xml(exp_str) == exp_obj

        exp_str = """<valid attribute="'"/>"""
        exp_obj = Dict("attribute" => "'")
        @test Serde.parse_xml(exp_str) == exp_obj

        exp_str = """<valid attribute='"'/>"""
        exp_obj = Dict("attribute" => "\"")
        @test Serde.parse_xml(exp_str) == exp_obj

        exp_str = """
        <valid>
          <!-- "'<>& comment -->
        </valid>
        """
        exp_obj = Dict()
        @test Serde.parse_xml(exp_str) == exp_obj

        exp_str = """<valid><![CDATA[<sender>John Smith</sender>]]></valid>"""
        exp_obj = Dict("_" => "<sender>John Smith</sender>")
        @test Serde.parse_xml(exp_str) == exp_obj
    end

    @testset "Case №3: Exceptions tests" begin
        exp_str = """
        <wrong_order>
          <?xml version="1.0" encoding="UTF-8"?>
        </wrong_order>
        """
        @test_throws Serde.ParXml.XmlSyntaxError Serde.parse_xml(exp_str)

        exp_str = """
        <root>
          <base>qwerty</base>
          <unclosed_tag>
        </root>
        """
        @test_throws Serde.ParXml.XmlSyntaxError Serde.parse_xml(exp_str)

        exp_str = """
        <wrong_order>
          <tag>
          </wrong_order>
        </tag>
        """
        @test_throws Serde.ParXml.XmlSyntaxError Serde.parse_xml(exp_str)
    end

    @testset "Case №4: Attributes tests" begin
        exp_str = """
        <root>
          <tag attribute="value"></tag>
          <tag attribute="value" attribute2="value2"></tag>
          <tag attribute="value" attribute2="value2" attribute3="value3"></tag>
        </root>
        """
        exp_obj = Dict(
            "tag" => Dict[
                Dict("attribute" => "value"),
                Dict("attribute" => "value", "attribute2" => "value2"),
                Dict(
                    "attribute" => "value",
                    "attribute2" => "value2",
                    "attribute3" => "value3",
                ),
            ],
        )
        @test Serde.parse_xml(exp_str) == exp_obj
    end

    @testset "Case №5: Mixed tests" begin
        exp_str = """
        <root>
          <tag attribute="value">text</tag>
          <tag attribute="value" attribute2="value2">text</tag>
          <tag attribute="value" attribute2="value2" attribute3="value3">text</tag>
        </root>
        """
        exp_obj = Dict(
            "tag" => Dict[
                Dict("attribute" => "value", "_" => "text"),
                Dict("attribute" => "value", "attribute2" => "value2", "_" => "text"),
                Dict(
                    "attribute" => "value",
                    "attribute2" => "value2",
                    "attribute3" => "value3",
                    "_" => "text",
                ),
            ],
        )
        @test Serde.parse_xml(exp_str) == exp_obj
    end

    @testset "Case №6: HTML tests" begin
        exp_str = """
        <!DOCTYPE html>
        <html>
          <head>
            <title>HTML</title>
          </head>
          <body>
            <h1>HTML</h1>
            <p>HTML is a markup language.</p>
          </body>
        </html>
        """
        exp_obj = Dict(
            "head" => Dict("title" => Dict("_" => "HTML")),
            "body" => Dict(
                "h1" => Dict("_" => "HTML"),
                "p" => Dict("_" => "HTML is a markup language."),
            ),
        )
        @test Serde.parse_xml(exp_str) == exp_obj
    end

    @testset "Case №7: HTML with links tests" begin
        exp_str = """
        <!DOCTYPE html>
        <html>
          <head>
            <title>HTML</title>
          </head>
          <body>
            <h1>Julia</h1>
            <p>Julia is a high-level, high-performance dynamic programming language.</p>
            <a href="https://julialang.org">Julia</a>
            </body>
        </html>
        """
        exp_obj = Dict(
            "head" => Dict("title" => Dict("_" => "HTML")),
            "body" => Dict(
                "h1" => Dict("_" => "Julia"),
                "p" => Dict(
                    "_" => "Julia is a high-level, high-performance dynamic programming language.",
                ),
                "a" => Dict("href" => "https://julialang.org", "_" => "Julia"),
            ),
        )
        @test Serde.parse_xml(exp_str) == exp_obj
    end

    @testset "Case №8: Parse XML with other Dict types" begin
        exp_str = """
        <root>
          <tag attribute="value">text</tag>
          <tag attribute="value" attribute2="value2">text</tag>
          <tag attribute="value" attribute2="value2" attribute3="value3">text</tag>
        </root>
        """
        exp_obj = IdDict(
            "tag" => IdDict[
                IdDict("attribute" => "value", "_" => "text"),
                IdDict("attribute" => "value", "attribute2" => "value2", "_" => "text"),
                IdDict(
                    "attribute" => "value",
                    "attribute2" => "value2",
                    "attribute3" => "value3",
                    "_" => "text",
                ),
            ],
        )
        @test Serde.parse_xml(exp_str, dict_type = IdDict) == exp_obj
    end
end
