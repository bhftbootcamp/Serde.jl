# Par/ParYaml

ext = Serde.Ext.YAML()

@testset verbose = true "ParYaml" begin
    @testset "Case №1: Simple YAML" begin
        exp_str = """
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
        exp_obj = Dict(
            "dict" => Dict("dict_key_2" => "dict_value_2", "dict_key_1" => "dict_value_1"),
            "string" => "qwerty",
            "list" => Dict[
                Dict("int" => 163, "string" => "foo", "quoted" => "bar", "float" => 1.63),
                Dict("string" => "baz", "braces" => "{{ dd }}"),
            ],
            "date" => Date("2024-01-01"),
        )
        @test Serde.parse_yaml(exp_str) == exp_obj
    end

    @testset "Case №2: YAML with anchors and multilines" begin
        exp_str = """
        anchorTest: &myAnchor
          toSingleLine: >
            this text will be considered on a
            single line
          toMultiline: |
            this text will be considered
            on multiple lines
        aliasTest: *myAnchor
        """
        exp_obj = Dict(
            "anchorTest" => Dict(
                "toMultiline" => "this text will be considered\non multiple lines\n",
                "toSingleLine" => "this text will be considered on a single line\n",
            ),
            "aliasTest" => Dict(
                "toMultiline" => "this text will be considered\non multiple lines\n",
                "toSingleLine" => "this text will be considered on a single line\n",
            ),
        )
        @test Serde.parse_yaml(exp_str) == exp_obj
    end

    @testset "Case №3: Boolean test" begin
        exp_str = """
        boolTrue1: True
        boolTrue2: true
        boolFalse1: False
        boolFalse2: false
        boolYes: !!bool Yes
        boolNo: !!bool No
        boolOn: !!bool On
        boolOff: !!bool Off
        """
        exp_obj = Dict(
            "boolNo" => false,
            "boolTrue2" => true,
            "boolOff" => false,
            "boolTrue1" => true,
            "boolOn" => true,
            "boolFalse2" => false,
            "boolFalse1" => false,
            "boolYes" => true,
        )
        @test Serde.parse_yaml(exp_str) == exp_obj
    end

    @testset "Case №4: Exceptions tests" begin
        exp_str = "vector: [3,,4]"
        @test_throws ext.ParYaml.YamlSyntaxError Serde.parse_yaml(exp_str)
    end

    @testset "Case №5: Different Dict type" begin
        exp_str = """
        foo: 163
        bar: true
        """
        exp_obj = IdDict("foo" => 163, "bar" => true)
        @test ext.ParYaml.parse_yaml(exp_str; dict_type = IdDict) == exp_obj
    end
end
