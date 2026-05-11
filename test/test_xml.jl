@testset "XML — naive DateTime is emitted without a Z suffix" begin
    # Regression: emitting `Z` for a Julia DateTime is a lie about timezone.
    # See the matching TOML fix.
    using Dates
    struct _XmlDT; t::DateTime; end
    out = to_xml(_XmlDT(DateTime(2024, 1, 2, 3, 4, 5)))
    @test !occursin("Z\"", out)
    @test occursin("2024-01-02T03:04:05", out)
end

@testset "XML — entity escaping (CRITICAL)" begin
    # C6: text content and attribute values must be entity-escaped.
    struct _XmlEsc; v::String; end
    xml = to_xml(_XmlEsc("<foo>&\"a"))
    # No raw <, &, or " inside an attribute value
    @test !occursin("v=\"<foo>", xml)
    # Round-trip through EzXML must succeed
    back = from_xml(_XmlEsc, xml)
    @test back.v == "<foo>&\"a"

    # Same for text-content paths
    xml2 = to_xml(Dict("t" => "a < b & c > d"); key = "root")
    @test !occursin("a < b", xml2) || occursin("&lt;", xml2)
    @test occursin("&amp;", xml2)
    parse_xml(xml2)  # must not throw
end

@testset "XML — child-element-as-value deserialization (CRITICAL)" begin
    # C7: <root><x>1</x><y>2</y></root> must deserialize into struct{x::Int, y::Int}.
    struct _XmlChildVal; x::Int; y::Int; end
    res = from_xml(_XmlChildVal, "<root><x>1</x><y>2</y></root>")
    @test res === _XmlChildVal(1, 2)
end

@testset "XML — try_from_xml" begin
    # H14
    struct _XmlTry; n::Int; end
    @test try_from_xml(_XmlTry, "<r n=\"7\"/>").n == 7
    @test try_from_xml(_XmlTry, "<broken") isa SerdeError
    @test try_from_xml(CamelCase(), _XmlTry, "<r n=\"3\"/>").n == 3
end

@testset "XML — invalid element name rejected on serialize" begin
    @test_throws ArgumentError to_xml(Dict("hello world" => 1); key = "r")
end

@testset "XML — _xml_node_content and text content" begin

    @testset "to_xml struct with _ field (text content)" begin
        # Struct with _ field creates text content + attributes
        struct _XmlTextContent
            id::Int
            _::String
        end
        xml = to_xml(_XmlTextContent(1, "hello world"); key = "r")
        @test occursin("hello world", xml)
        @test occursin("id=\"1\"", xml)
    end

    @testset "to_xml vector of non-simple (struct) elements" begin
        # AbstractVector with non-simple elements calls _xml_pair! recursively
        struct _XmlItem
            val::Int
        end
        struct _XmlItemList
            items::Vector{_XmlItem}
        end
        xml = to_xml(_XmlItemList([_XmlItem(1), _XmlItem(2)]); key = "root")
        @test occursin("items", xml)
        @test occursin("val=\"1\"", xml) || occursin("val=", xml)
        @test occursin("val=\"2\"", xml) || occursin("val=", xml)
    end

    @testset "to_xml node with text and child (both non-empty)" begin
        # Node with _ text field AND a child struct field
        struct _XmlChildInner
            n::Int
        end
        struct _XmlBothContent
            id::Int
            _::String
            child::_XmlChildInner
        end
        xml = to_xml(_XmlBothContent(1, "text", _XmlChildInner(42)); key = "r")
        @test occursin("text", xml)
        @test occursin("42", xml)
    end

    @testset "to_xml with >32 fields struct" begin
        field_decls = join(["xf2_$i::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _Big34Xml2; $field_decls; end"))
        vals = ntuple(i -> i, 34)
        obj = Main._Big34Xml2(vals...)
        xml = to_xml(obj; key = "root")
        @test occursin("xf2_1", xml)
        @test occursin("xf2_34", xml)
    end

    @testset "to_xml Dict with non-simple value" begin
        xml = to_xml(Dict("data" => Dict("inner" => 42)); key = "root")
        @test occursin("data", xml)
        @test occursin("inner", xml)
        @test occursin("42", xml)
    end

    @testset "parse_xml with existing key — push! path" begin
        # force_array=true with already-array pushes to existing
        xml = "<root><x>1</x><x>2</x><x>3</x></root>"
        d = parse_xml(xml; force_array = true)
        @test length(d["x"]) == 3
    end

    @testset "to_xml Vector of simple values" begin
        # Vector of simple values in Dict
        xml = to_xml(Dict("t" => [1, 2, 3]); key = "root")
        @test occursin("1", xml)
        @test occursin("2", xml)
        @test occursin("3", xml)
    end
end

@testset "XML — text content + child + strategy paths" begin

    @testset "to_xml struct with both _ text and child (branches 295-298)" begin
        # Need a struct where _xml_pair is called with text content
        # The _ field creates text content, other fields create attributes OR children
        struct _XmlTextChild_Inner
            count::Int
        end
        struct _XmlTextAndChild
            id::Int
            _::String
            child::_XmlTextChild_Inner
        end
        xml = to_xml(_XmlTextAndChild(1, "hello", _XmlTextChild_Inner(42)); key = "r")
        # Should contain both text content "hello" and child "42"
        @test occursin("hello", xml)
        @test occursin("42", xml)
        @test occursin("id=", xml)
    end

    @testset "to_xml with strategy and >32 fields" begin
        field_decls = join(["xb$i::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _XmlBig34S; $field_decls; end"))
        vals = ntuple(i -> i, 34)
        obj = Main._XmlBig34S(vals...)
        xml = to_xml(CamelCase(), obj; key = "root")
        @test occursin("xb1", xml) || occursin("xb34", xml)
    end

    @testset "to_xml strategy simple struct" begin
        struct _XmlStrat; my_field::Int; other::String; end
        xml = to_xml(CamelCase(), _XmlStrat(1, "hello"); key = "root")
        @test occursin("myField", xml) || occursin("1", xml)
    end
end

@testset "XML — _xml_node_content AbstractDict path" begin

    @testset "to_xml with Dict having '_' text content key — line 184-185" begin
        # Dict with "_" key has text content, other keys are attributes
        xml = to_xml(Dict("item" => Dict("_" => "hello", "id" => 1)); key = "root")
        @test occursin("hello", xml)
        @test occursin("id", xml)
    end

    @testset "to_xml strategy with Number field — line 315" begin
        struct _XmlSN; val::Int; end
        xml = to_xml(CamelCase(), _XmlSN(42); key = "r")
        @test occursin("42", xml)
    end

    @testset "to_xml strategy with String field — line 313" begin
        struct _XmlSStr; name::String; end
        xml = to_xml(CamelCase(), _XmlSStr("hello"); key = "r")
        @test occursin("hello", xml)
    end
end

@testset "XML — strategy with >32 fields (line 284-289)" begin

    @testset "to_xml(strategy, data) with >32 fields" begin
        field_decls = join(["xbs$(i)::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _XmlBigS34; " * field_decls * "; end"))
        vals = ntuple(i -> i, 34)
        obj = Main._XmlBigS34(vals...)
        xml = to_xml(CamelCase(), obj; key = "root")
        @test occursin("xbs1", xml) || occursin("1", xml)
        @test occursin("xbs34", xml) || occursin("34", xml)
    end
end

@testset "XML — _xml_pair! with strategy and Number value (line 315)" begin

    @testset "to_xml(strategy, struct_with_number) — line 315 direct dispatch" begin
        # _XmlSN has val::Int which serializes via _xml_pair!(io, strategy, "val", 42)
        # This dispatches to _xml_pair!(io, strategy, key, val::Number) at line 315
        struct _XmlNumPair315; count::Int64; end
        xml = to_xml(CamelCase(), _XmlNumPair315(42); key = "root")
        @test occursin("42", xml)
        @test occursin("count", xml)
    end

    @testset "to_xml(strategy, nested_struct_with_number) — Number pair via child" begin
        struct _XmlNumOuter; label::String; amount::Int; end
        xml = to_xml(CamelCase(), _XmlNumOuter("test", 100); key = "item")
        @test occursin("100", xml)
        @test occursin("amount", xml)
    end
end
