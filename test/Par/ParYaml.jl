# Par/ParYaml

@testset verbose = true "ParYaml" begin
    @testset "Case №1: Simple YAML" begin
        source = """
        string: qwerty
        date: 2024-01-01
        dict:
          dict_key_1: dict_value_1 #comment
          dict_key_2: dict_value_2
        list:
          - string: foo
            quoted: 'bar'
            float: 1.63
            int: 163
          - string: baz
            braces: "{{ dd }}"
        """
        parsed = Dict{String, Any}(
            "dict" => Dict{String, Any}(
                "dict_key_2" => "dict_value_2", 
                "dict_key_1" => "dict_value_1"
            ), 
            "string" => "qwerty", 
            "list" => Dict{String, Any}[
                Dict(
                    "int" => 163, 
                    "string" => "foo", 
                    "quoted" => "bar", 
                    "float" => 1.63
                ), 
                Dict(
                    "string" => "baz", 
                    "braces" => "{{ dd }}"
                )
            ],
            "date" => Date("2024-01-01")
        )

        @test Serde.parse_yaml(source) == parsed
    end

    @testset "Case №2: YAML with anchors and multilines" begin
        source = """
        anchorTest: &myAnchor
          toSingleLine: >
            this text will be considered on a
            single line
          toMultiline: |
            this text will be considered 
            on multiple lines
        aliasTest: *myAnchor
        """
        parsed = Dict{String, Any}(
            "anchorTest" => Dict{String, Any}(
                "toMultiline" => "this text will be considered \non multiple lines\n", 
                "toSingleLine" => "this text will be considered on a single line\n"
            ), 
            "aliasTest" => Dict{String, Any}(
                "toMultiline" => "this text will be considered \non multiple lines\n", 
                "toSingleLine" => "this text will be considered on a single line\n"
            )
        )

        @test Serde.parse_yaml(source) == parsed
    end

    @testset "Case №3: Boolean test" begin
        source = """
        boolTrue1: True
        boolTrue2: true
        boolFalse1: False
        boolFalse2: false
        boolYes: !!bool Yes
        boolNo: !!bool No
        boolOn: !!bool On
        boolOff: !!bool Off
        """
        parsed = Dict{String, Any}(
            "boolNo" => false, 
            "boolTrue2" => true, 
            "boolOff" => false, 
            "boolTrue1" => true, 
            "boolOn" => true, 
            "boolFalse2" => false, 
            "boolFalse1" => false, 
            "boolYes" => true
        )

        @test Serde.parse_yaml(source) == parsed
    end

    @testset "Case №4: Exceptions tests" begin
        source = "vector: [3,,4]"

        @test_throws Serde.ParYaml.YamlSyntaxError Serde.parse_yaml(source)
    end
end
