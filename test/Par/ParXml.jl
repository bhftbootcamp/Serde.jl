# Par/ParXml

@testset verbose = true "ParXml" begin
    @testset "Case №1: Normal XML" begin
        xml = """
          <computers description="Office Computers">
              <computer name="Dell" cpu="Intel" ram="16" storage="512" release_year="2020" has_ssd="true">
                  <operating_systems type="Desktop">
                      <os name="Windows" version="10"/>
                      <os name="Ubuntu" version="20.04"/>
                  </operating_systems>
                  <ports>
                      <port type="USB" version="3.0"/>
                      <port type="HDMI" version="2.0"/>
                  </ports>
              </computer>
              <computer name="Asus" cpu="AMD" ram="8" storage="256" release_year="2021" has_ssd="false">
                  <operating_systems type="Gaming">
                      <os name="Windows" version="11"/>
                      <os name="Fedora" version="33"/>
                  </operating_systems>
                  <ports>
                      <port type="USB" version="3.1"/>
                      <port type="DisplayPort" version="1.4"/>
                  </ports>
              </computer>
              <tag name="Dell">2000</tag>
          </computers>
        """
        exp = Dict{String,Any}(
            "tag" => Dict{String,Any}("name" => "Dell", "_" => "2000"),
            "computer" => Dict{String,Any}[
                Dict(
                    "name" => "Dell",
                    "operating_systems" => Dict{String,Any}(
                        "type" => "Desktop",
                        "os" => Dict{String,Any}[
                            Dict("name" => "Windows", "version" => "10"),
                            Dict("name" => "Ubuntu", "version" => "20.04"),
                        ],
                    ),
                    "cpu" => "Intel",
                    "ram" => "16",
                    "storage" => "512",
                    "has_ssd" => "true",
                    "release_year" => "2020",
                    "ports" => Dict{String,Any}(
                        "port" => Dict{String,Any}[
                            Dict("type" => "USB", "version" => "3.0"),
                            Dict("type" => "HDMI", "version" => "2.0"),
                        ],
                    ),
                ),
                Dict(
                    "name" => "Asus",
                    "operating_systems" => Dict{String,Any}(
                        "type" => "Gaming",
                        "os" => Dict{String,Any}[
                            Dict("name" => "Windows", "version" => "11"),
                            Dict("name" => "Fedora", "version" => "33"),
                        ],
                    ),
                    "cpu" => "AMD",
                    "ram" => "8",
                    "storage" => "256",
                    "has_ssd" => "false",
                    "release_year" => "2021",
                    "ports" => Dict{String,Any}(
                        "port" => Dict{String,Any}[
                            Dict("type" => "USB", "version" => "3.1"),
                            Dict("type" => "DisplayPort", "version" => "1.4"),
                        ],
                    ),
                ),
            ],
            "description" => "Office Computers",
        )
        @test Serde.parse_xml(xml) == exp
    end

    @testset "Case №2: Array XML" begin
        xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <root>
          <level category="string">
            <single>Single string</single>
          </level>
          <level category="array">
            <string>there are</string>
            <string>three identical</string>
            <string>tags here</string>
          </level>
        </root>
        """
        exp = Dict{String,Any}(
            "level" => Any[
                Dict{String,Any}("category" => "string", "single" => "Single string"),
                Dict{String,Any}(
                    "string" => Any["there are", "three identical", "tags here"],
                    "category" => "array",
                ),
            ],
        )
        @test Serde.parse_xml(xml) == exp
    end

    @testset "Case №3: Escape characters" begin
        xml = """<valid>"'></valid>"""
        exp = "\"'>"
        @test Serde.parse_xml(xml) == exp

        xml = """<valid attribute=">"/>"""
        exp = Dict{String,Any}("attribute" => ">")
        @test Serde.parse_xml(xml) == exp

        xml = """<valid attribute="'"/>"""
        exp = Dict{String,Any}("attribute" => "'")
        @test Serde.parse_xml(xml) == exp

        xml = """<valid attribute='"'/>"""
        exp = Dict{String,Any}("attribute" => "\"")
        @test Serde.parse_xml(xml) == exp

        xml = """
        <valid>
          <!-- "'<>& comment -->
        </valid>
        """
        exp = Dict{String,Any}()
        @test Serde.parse_xml(xml) == exp

        xml = "<valid><![CDATA[<sender>John Smith</sender>]]></valid>"
        exp = "<sender>John Smith</sender>"
        @test Serde.parse_xml(xml) == exp
    end

    @testset "Case №4: Exception testing" begin
        xml = """
        <wrong_order>
          <?xml version="1.0" encoding="UTF-8"?>
        </wrong_order>
        """
        @test_throws Serde.ParXml.XmlSyntaxError Serde.parse_xml(xml)

        xml = """
        <root>
          <base>qwerty</base>
          <unclosed_tag>
        </root>
        """
        @test_throws Serde.ParXml.XmlSyntaxError Serde.parse_xml(xml)

        xml = """
        <wrong_order>
          <tag>
          </wrong_order>
        </tag>
        """
        @test_throws Serde.ParXml.XmlSyntaxError Serde.parse_xml(xml)
    end

    @testset "Case №5: Parse with root level" begin
        xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <root>
          <first attr="attr_value">
            <second>qwerty</second>
          </first>
        </root>
        """
        exp = Dict{String,Any}(
            "root" => Dict{String,Any}(
                "first" =>
                    Dict{String,Any}("second" => "qwerty", "attr" => "attr_value"),
            ),
            "encoding" => "UTF-8",
            "version" => "1.0",
        )
        @test Serde.parse_xml(xml; decl_struct = true) == exp
    end
end
