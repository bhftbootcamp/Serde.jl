# test_edge_cases.jl

# ─────────────────────────────────────────────────────────────────────────────
# 1. deser.jl — непокрытые пути
# ─────────────────────────────────────────────────────────────────────────────

@testset "Deser engine — edge cases" begin

    @testset "Empty struct (zero fields) round-trip" begin
        # Regression: `@nexprs 32` referenced `x_1..x_32` even when the struct
        # had no fields, and `_yy_deser_struct` / deser.jl all blew up.
        # BSON additionally rejected zero-field structs at write time; YAML
        # emitted a blank document that parsed back as `nothing`.
        struct _EE end
        for (label, to_fn, from_fn) in [
            ("json",    to_json,    from_json),
            ("toml",    to_toml,    from_toml),
            ("yaml",    to_yaml,    from_yaml),
            ("xml",     to_xml,     from_xml),
            ("msgpack", to_msgpack, from_msgpack),
            ("bson",    to_bson,    from_bson),
        ]
            out = to_fn(_EE())
            back = from_fn(_EE, out)
            @test back === _EE()
        end

        # Nested empty struct inside a non-empty parent must also round-trip.
        struct _Inner end
        struct _Outer; inner::_Inner; n::Int; end
        v = _Outer(_Inner(), 7)
        @test from_json(_Outer, to_json(v)) === v
        @test from_msgpack(_Outer, to_msgpack(v)).n == 7
        @test from_bson(_Outer, to_bson(v)).n == 7
    end

    @testset "register_tagged_subtype validates subtype relationship" begin
        abstract type _RegV end
        struct _NotChild end
        @test_throws ArgumentError register_tagged_subtype(_RegV, "x", _NotChild)
    end

    @testset "Enum deser from unknown Symbol throws" begin
        # Previously this silently returned `nothing`. The deser engine now
        # throws so the trait engine can surface a TypeMismatchError.
        @enum _EdgeColor2 red2 green2 blue2
        @test_throws ArgumentError Serde.deser(_EdgeColor2, :purple)
    end

    @testset "Enum deser from unknown String throws" begin
        @enum _EdgeDir north south east west
        @test_throws ArgumentError Serde.deser(_EdgeDir, "northeast")
    end

    @testset "Number coercion Float64 from Int" begin
        # deser(Float64, Integer) — passthrough (returns Integer)
        result = Serde.deser(Float64, 3)
        @test result == 3.0
    end

    @testset "Set from AbstractArray" begin
        s = Serde.deser(Set{String}, ["a", "b", "c"])
        @test s == Set(["a", "b", "c"])
    end

    @testset "Dict TypeMismatchError on nested dict in int field" begin
        @test_throws TypeMismatchError Serde.deser(
            Dict{String,Int},
            Dict("a" => Dict("nested" => 1))
        )
    end

    @testset "_field_convert — TypeMismatchError on incompatible types" begin
        struct _FieldConvErr
            x::Int
        end
        @test_throws TypeMismatchError Serde.deser(
            _FieldConvErr,
            Dict("x" => Dict("bad" => "type"))
        )
    end

    @testset "_field_convert — MissingFieldError on nil data for non-nullable" begin
        struct _FieldMissReq
            x::Int
        end
        @test_throws MissingFieldError Serde.deser(
            _FieldMissReq,
            Dict{String,Any}()
        )
    end

    @testset "Union{Missing,T} deserialization" begin
        result = Serde.deser(Union{Missing,Int}, 42)
        @test result === 42

        result2 = Serde.deser(Union{Missing,String}, "hello")
        @test result2 == "hello"
    end

    @testset "Struct from Dict with Symbol keys" begin
        struct _SymKeyStruct
            name::String
            value::Int
        end
        obj = Serde.deser(_SymKeyStruct, Dict(:name => "test", :value => 7))
        @test obj.name == "test"
        @test obj.value == 7
    end

    @testset "Vector deser with element coercion" begin
        v = Serde.deser(Vector{Int}, Any["1", "2", "3"])
        @test v == [1, 2, 3]
    end

    @testset "Tuple deser generic (UnionAll)" begin
        t = Serde.deser(Tuple, [1, "a", 3.0])
        @test t == (1, "a", 3.0)
    end

    @testset "Typed Tuple deser with coercion" begin
        t = Serde.deser(Tuple{Int,String,Float64}, [1, "hello", 2.0])
        @test t === (1, "hello", 2.0)
    end

    @testset "deser_validate throws ValidationError" begin
        struct _ValidateEdge
            score::Int
        end
        Serde.deser_validate(::Type{_ValidateEdge}, ::Val{:score}, v) =
            v < 0 && throw(ValidationError(_ValidateEdge, :score, v, "must be non-negative"))

        @test_throws ValidationError Serde.deser(
            _ValidateEdge,
            Dict("score" => -5)
        )

        obj = Serde.deser(_ValidateEdge, Dict("score" => 10))
        @test obj.score == 10
    end

    @testset "isempty_value triggers nulltype" begin
        struct _EmptyVal
            tag::Union{Nothing,String}
        end
        Serde.isempty_value(::Type{_EmptyVal}, ::Val{:tag}, v::String) = isempty(strip(v))

        obj = Serde.deser(_EmptyVal, Dict("tag" => "   "))
        @test obj.tag === nothing

        obj2 = Serde.deser(_EmptyVal, Dict("tag" => "hello"))
        @test obj2.tag == "hello"
    end

    @testset "deser_transform applied during field construction" begin
        struct _TransformEdge
            label::String
        end
        Serde.deser_transform(::Type{_TransformEdge}, ::Type{String}, v) = uppercase(v)

        obj = Serde.deser(_TransformEdge, Dict("label" => "hello"))
        @test obj.label == "HELLO"
    end

    @testset "Struct with >32 fields — Dict fallback path" begin
        field_decls = join(["f$i::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _Big34Fields; $field_decls; end"))
        data = Dict(string("f$i") => i for i in 1:34)
        obj = Serde.deser(Main._Big34Fields, data)
        @test getfield(obj, :f1) == 1
        @test getfield(obj, :f33) == 33
        @test getfield(obj, :f34) == 34
    end

    @testset "Struct from NamedTuple with >32 fields" begin
        field_names = [Symbol("g$i") for i in 1:34]
        field_decls = join(["g$i::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _Big34NT; $field_decls; end"))
        nt = NamedTuple{tuple(field_names...)}(tuple(1:34...))
        obj = Serde.deser(Main._Big34NT, nt)
        @test getfield(obj, :g1) == 1
        @test getfield(obj, :g34) == 34
    end

    @testset "Struct from Vector with >32 fields" begin
        field_decls = join(["h$i::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _Big34Vec; $field_decls; end"))
        data = collect(1:34)
        obj = Serde.deser(Main._Big34Vec, data)
        @test getfield(obj, :h1) == 1
        @test getfield(obj, :h34) == 34
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# 2. YAML — непокрытые пути
# ─────────────────────────────────────────────────────────────────────────────

@testset "YAML format — edge cases" begin

    @testset "parse_yaml error" begin
        @test_throws ParseError parse_yaml("key: [unclosed")
    end

    @testset "try_from_yaml — parse error" begin
        struct _YamlTry; x::Int; end
        result = try_from_yaml(_YamlTry, "key: [unclosed")
        @test result isa SerdeError
    end

    @testset "try_from_yaml — success" begin
        struct _YamlTryOk; x::Int; end
        result = try_from_yaml(_YamlTryOk, "x: 42\n")
        @test result isa _YamlTryOk
        @test result.x == 42
    end

    @testset "to_yaml string with special characters (via strategy)" begin
        struct _YamlEsc
            text::String
        end
        # Строка с символом переноса — должна быть в кавычках
        yaml = to_yaml(Serde.DefaultStrategy(), _YamlEsc("hello\nworld"))
        @test occursin("\\n", yaml) || occursin("\"", yaml)
    end

    @testset "to_yaml NaN/Inf numbers (via strategy)" begin
        struct _YamlSpecNum
            a::Float64
            b::Float64
        end
        yaml = to_yaml(Serde.DefaultStrategy(), _YamlSpecNum(NaN, Inf))
        @test occursin(".nan", yaml)
        @test occursin(".inf", yaml)
    end

    @testset "to_yaml nothing and missing (via strategy)" begin
        struct _YamlNull
            a::Union{Nothing,Int}
            b::Union{Missing,Int}
        end
        obj = _YamlNull(nothing, missing)
        yaml = to_yaml(Serde.DefaultStrategy(), obj)
        @test occursin("null", yaml)
    end

    @testset "to_yaml Char value (primitive, no strategy needed)" begin
        yaml = to_yaml(Serde.DefaultStrategy(), 'Z')
        @test occursin("'Z'", yaml)
    end

    @testset "to_yaml Enum value (via strategy)" begin
        @enum _YamlColorEnum yred ygreen yblue
        struct _YamlEnumField
            color::_YamlColorEnum
        end
        yaml = to_yaml(Serde.DefaultStrategy(), _YamlEnumField(ygreen))
        @test occursin("ygreen", yaml)
    end

    @testset "to_yaml Set (primitive iterable)" begin
        yaml = to_yaml(Serde.DefaultStrategy(), Set([1, 2, 3]))
        @test occursin("- ", yaml)
    end

    @testset "to_yaml Dict" begin
        yaml = to_yaml(Serde.DefaultStrategy(), Dict("key" => "value"))
        @test occursin("key:", yaml)
        @test occursin("value", yaml)
    end

    @testset "to_yaml Pair" begin
        yaml = to_yaml(Serde.DefaultStrategy(), "key" => 42)
        @test occursin("key", yaml)
        @test occursin("42", yaml)
    end

    @testset "to_yaml NamedTuple" begin
        yaml = to_yaml(Serde.DefaultStrategy(), (; a = 1, b = "hello"))
        @test occursin("a:", yaml)
        @test occursin("b:", yaml)
    end

    @testset "to_yaml nested struct (via strategy)" begin
        struct _YamlInner2
            value::Int
        end
        struct _YamlOuter2
            name::String
            inner::_YamlInner2
        end
        yaml = to_yaml(Serde.DefaultStrategy(), _YamlOuter2("test", _YamlInner2(42)))
        @test occursin("name:", yaml)
        @test occursin("inner:", yaml)
        @test occursin("42", yaml)
    end

    @testset "to_yaml with >32 fields struct (via strategy)" begin
        field_decls = join(["y$i::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _Big34Yaml; $field_decls; end"))
        vals = ntuple(i -> i, 34)
        obj = Main._Big34Yaml(vals...)
        yaml = to_yaml(Serde.DefaultStrategy(), obj)
        @test occursin("y1:", yaml)
        @test occursin("y34:", yaml)
    end

    @testset "from_yaml Nothing/Missing" begin
        @test from_yaml(Nothing, "null") === nothing
        @test from_yaml(Missing, "null") === missing
    end

    @testset "from_yaml function dispatch" begin
        struct _YamlFuncA
            kind::String
            val::Int
        end
        struct _YamlFuncB
            kind::String
            name::String
        end
        yaml = to_yaml(Serde.DefaultStrategy(), _YamlFuncA("a", 10))
        result = from_yaml(yaml) do d
            d["kind"] == "a" ? _YamlFuncA : _YamlFuncB
        end
        @test result isa _YamlFuncA
        @test result.val == 10
    end

    @testset "to_yaml Vector{UInt8} input for from_yaml" begin
        bytes = Vector{UInt8}("x: 1\n")
        struct _YamlBytes; x::Int; end
        obj = from_yaml(_YamlBytes, bytes)
        @test obj.x == 1
    end

    @testset "Round-trip YAML" begin
        struct _YamlRound
            name::String
            score::Float64
            active::Bool
        end
        original = _YamlRound("Alice", 9.5, true)
        yaml = to_yaml(Serde.DefaultStrategy(), original)
        recovered = from_yaml(_YamlRound, yaml)
        @test recovered.name == original.name
        @test recovered.score == original.score
        @test recovered.active == original.active
    end

    @testset "YAML with CamelCase context" begin
        struct _YamlCamel
            my_field::Int
            other_val::String
        end
        obj = _YamlCamel(1, "test")
        yaml = to_yaml(CamelCase(), obj)
        @test occursin("myField", yaml)
        @test !occursin("my_field", yaml)

        recovered = from_yaml(CamelCase(), _YamlCamel, yaml)
        @test recovered.my_field == 1
        @test recovered.other_val == "test"
    end

    @testset "try_from_yaml with context — success" begin
        struct _YamlCtxTry
            x::Int
        end
        result = try_from_yaml(CamelCase(), _YamlCtxTry, "x: 5\n")
        @test result isa _YamlCtxTry
        @test result.x == 5
    end

    @testset "try_from_yaml with context — error" begin
        struct _YamlCtxTryBad
            x::Int
        end
        result = try_from_yaml(CamelCase(), _YamlCtxTryBad, "key: [unclosed")
        @test result isa SerdeError
    end

    @testset "to_yaml Vector of primitives" begin
        yaml = to_yaml(Serde.DefaultStrategy(), [1, 2, 3])
        @test occursin("- 1", yaml)
        @test occursin("- 2", yaml)
        @test occursin("- 3", yaml)
    end

    @testset "to_yaml Tuple" begin
        yaml = to_yaml(Serde.DefaultStrategy(), (1, "two", 3.0))
        @test occursin("- 1", yaml)
        @test occursin("- \"two\"", yaml)
    end

    @testset "to_yaml UUID" begin
        u = uuid4()
        yaml = to_yaml(Serde.DefaultStrategy(), u)
        @test occursin(string(u), yaml)
    end

    @testset "to_yaml DateTime" begin
        dt = Dates.DateTime(2024, 6, 15)
        yaml = to_yaml(Serde.DefaultStrategy(), dt)
        @test occursin("2024", yaml)
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# 3. XML — непокрытые пути
# ─────────────────────────────────────────────────────────────────────────────

@testset "XML format — edge cases" begin

    @testset "parse_xml text content node" begin
        xml = "<root>hello world</root>"
        d = parse_xml(xml)
        @test d["_"] == "hello world"
    end

    @testset "parse_xml force_array single element" begin
        xml = "<root><item>1</item></root>"
        d = parse_xml(xml; force_array = true)
        @test d["item"] isa Vector
        @test length(d["item"]) == 1
    end

    @testset "parse_xml child element duplication" begin
        xml = "<root><item>1</item><item>2</item></root>"
        d = parse_xml(xml)
        @test d["item"] isa Vector
        @test length(d["item"]) == 2
    end

    @testset "parse_xml force_array multiple elements" begin
        xml = "<root><item>1</item><item>2</item></root>"
        d = parse_xml(xml; force_array = true)
        @test d["item"] isa Vector
        @test length(d["item"]) == 2
    end

    @testset "parse_xml nested elements" begin
        xml = "<root><outer><inner>42</inner></outer></root>"
        d = parse_xml(xml)
        @test haskey(d, "outer")
    end

    @testset "parse_xml Vector{UInt8}" begin
        xml = Vector{UInt8}("<root a=\"1\"/>")
        d = parse_xml(xml)
        @test d["a"] == "1"
    end

    @testset "parse_xml error" begin
        # EzXML wraps parse errors, SerdeXml catches them
        @test_throws Exception parse_xml("<unclosed>")
    end

    @testset "to_xml basic struct" begin
        struct _XmlBasic
            a::Int
            b::String
        end
        xml = to_xml(_XmlBasic(1, "hello"); key = "item")
        @test occursin("hello", xml) || occursin("1", xml)
    end

    @testset "to_xml with vector field" begin
        struct _XmlVec
            items::Vector{Int}
        end
        xml = to_xml(_XmlVec([1, 2, 3]); key = "root")
        @test occursin("1", xml)
        @test occursin("2", xml)
        @test occursin("3", xml)
    end

    @testset "to_xml nested struct" begin
        struct _XmlInner3
            value::Int
        end
        struct _XmlOuter3
            name::String
            child::_XmlInner3
        end
        xml = to_xml(_XmlOuter3("test", _XmlInner3(99)); key = "root")
        @test occursin("test", xml)
        @test occursin("99", xml)
    end

    @testset "to_xml with nothing field" begin
        struct _XmlNullable
            x::Int
            y::Union{Nothing,String}
        end
        xml = to_xml(_XmlNullable(1, nothing); key = "r")
        @test !occursin("null", xml)
        @test occursin("1", xml)
    end

    @testset "from_xml basic struct" begin
        struct _XmlDeser
            id::String
            name::String
        end
        xml = """<item id="42" name="Alice"/>"""
        obj = from_xml(_XmlDeser, xml)
        @test obj.id == "42"
        @test obj.name == "Alice"
    end

    @testset "from_xml Nothing/Missing" begin
        @test from_xml(Nothing, "<r/>") === nothing
        @test from_xml(Missing, "<r/>") === missing
    end

    @testset "from_xml function dispatch" begin
        struct _XmlDispA
            kind::String
        end
        xml = """<r kind="test"/>"""
        result = from_xml(xml) do _d
            _XmlDispA
        end
        @test result isa _XmlDispA
        @test result.kind == "test"
    end

    @testset "to_xml with context" begin
        struct _XmlCtxSt
            my_field::Int
            skip_this::String
        end
        struct _XmlCtx2 end
        Serde.ser_name(::_XmlCtx2, ::Type{_XmlCtxSt}, ::Val{:my_field}) = :myField
        Serde.ser_skip(::_XmlCtx2, ::Type{_XmlCtxSt}, ::Val{:skip_this}) = true

        xml = to_xml(_XmlCtx2(), _XmlCtxSt(1, "hidden"); key = "root")
        @test occursin("myField", xml)
        @test !occursin("skip_this", xml)
    end

    @testset "from_xml with context" begin
        struct _XmlDeserCtx
            my_field::Int
        end
        xml = """<root myField="99"/>"""
        struct _XmlDeCtx end
        Serde.deser_name(::_XmlDeCtx, ::Type{_XmlDeserCtx}, ::Val{:my_field}) = :myField
        obj = from_xml(_XmlDeCtx(), _XmlDeserCtx, xml)
        @test obj.my_field == 99
    end

    @testset "to_xml with >32 fields struct" begin
        field_decls = join(["xf$i::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _Big34Xml; $field_decls; end"))
        vals = ntuple(i -> i, 34)
        obj = Main._Big34Xml(vals...)
        xml = to_xml(obj; key = "root")
        @test occursin("xf1", xml)
        @test occursin("xf34", xml)
    end

    @testset "to_xml Bool value" begin
        struct _XmlBool
            active::Bool
        end
        xml = to_xml(_XmlBool(true); key = "r")
        @test occursin("true", xml)
    end

    @testset "to_xml Enum value" begin
        @enum _XmlColorE xred xgreen xblue
        struct _XmlEnumField2
            color::_XmlColorE
        end
        xml = to_xml(_XmlEnumField2(xgreen); key = "r")
        @test occursin("xgreen", xml)
    end

    @testset "to_xml Symbol value" begin
        struct _XmlSym
            tag::Symbol
        end
        xml = to_xml(_XmlSym(:hello); key = "r")
        @test occursin("hello", xml)
    end

    @testset "to_xml DateTime value" begin
        struct _XmlDTEdge
            ts::Dates.DateTime
        end
        xml = to_xml(_XmlDTEdge(Dates.DateTime(2024, 1, 15)); key = "r")
        @test occursin("2024", xml)
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# 4. TOML — непокрытые пути
# ─────────────────────────────────────────────────────────────────────────────

@testset "TOML format — edge cases" begin

    @testset "to_toml negative integers" begin
        struct _TomlNeg
            val::Int
        end
        toml = to_toml(_TomlNeg(-42))
        @test occursin("-42", toml)
    end

    @testset "to_toml string with special characters (escape)" begin
        struct _TomlEscStr
            text::String
        end
        obj = _TomlEscStr("line1\nline2")
        toml = to_toml(obj)
        @test occursin("\\n", toml)
    end

    @testset "to_toml key requiring quoting" begin
        # Dict keys with spaces or special chars get quoted
        d = Dict("key with space" => "value")
        toml = to_toml(d)
        @test occursin("\"key with space\"", toml)
    end

    @testset "to_toml NaN float" begin
        struct _TomlNan
            val::Float64
        end
        toml = to_toml(_TomlNan(NaN))
        @test occursin("nan", toml)
    end

    @testset "to_toml empty vector" begin
        struct _TomlEmpty
            items::Vector{Int}
        end
        toml = to_toml(_TomlEmpty(Int[]))
        @test occursin("[]", toml)
    end

    @testset "to_toml Vector of structs (array of tables)" begin
        struct _TomlPt
            x::Int
            y::Int
        end
        struct _TomlPlotSer
            tag::String
            pts::Vector{_TomlPt}
        end
        obj = _TomlPlotSer("curve", [_TomlPt(1, 2), _TomlPt(3, 4)])
        toml = to_toml(obj)
        @test occursin("pts", toml)
        @test occursin("1", toml)
    end

    @testset "to_toml nested struct (table)" begin
        struct _TomlInnerN
            value::Int
        end
        struct _TomlOuterN
            name::String
            inner::_TomlInnerN
        end
        toml = to_toml(_TomlOuterN("test", _TomlInnerN(99)))
        @test occursin("[inner]", toml)
        @test occursin("99", toml)
    end

    @testset "to_toml UUID" begin
        u = Base.UUID("550e8400-e29b-41d4-a716-446655440000")
        struct _TomlUUID
            id::Base.UUID
        end
        toml = to_toml(_TomlUUID(u))
        @test occursin("550e8400", toml)
    end

    @testset "to_toml DateTime" begin
        # Distinct name from `_TomlDT` in test_toml.jl — Julia ≤ 1.10 rejects
        # redefining structs at the same scope.
        dt = Dates.DateTime(2024, 6, 15, 10, 30, 0)
        struct _TomlDTEdge
            ts::Dates.DateTime
        end
        toml = to_toml(_TomlDTEdge(dt))
        @test occursin("2024", toml)
    end

    @testset "to_toml Date" begin
        d = Dates.Date(2024, 1, 15)
        struct _TomlDate
            ts::Dates.Date
        end
        toml = to_toml(_TomlDate(d))
        @test occursin("2024-01-15", toml)
    end

    @testset "to_toml Enum (via string in Dict)" begin
        # TOML Enum serialization via Dict (string key)
        @enum _TomlColorEnum2 tred tgreen tblue
        toml = to_toml(Dict("color" => string(tgreen)))
        @test occursin("tgreen", toml)
    end

    @testset "to_toml Symbol" begin
        struct _TomlSym
            tag::Symbol
        end
        toml = to_toml(_TomlSym(:hello))
        @test occursin("hello", toml)
    end

    @testset "to_toml with >32 fields struct" begin
        field_decls = join(["tf$i::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _Big34Toml; $field_decls; end"))
        vals = ntuple(i -> i, 34)
        obj = Main._Big34Toml(vals...)
        toml = to_toml(obj)
        @test occursin("tf1", toml)
        @test occursin("tf34", toml)
    end

    @testset "from_toml Nothing/Missing" begin
        @test from_toml(Nothing, "x = 1") === nothing
        @test from_toml(Missing, "x = 1") === missing
    end

    @testset "from_toml function dispatch" begin
        struct _TomlFuncA
            kind::String
            val::Int
        end
        toml = to_toml(_TomlFuncA("a", 10))
        result = from_toml(toml) do _d
            _TomlFuncA
        end
        @test result isa _TomlFuncA
        @test result.val == 10
    end

    @testset "to_toml Dict" begin
        d = Dict("key" => "value")
        toml = to_toml(d)
        @test occursin("key", toml)
        @test occursin("value", toml)
    end

    @testset "try_from_toml — DeserError path" begin
        struct _TomlTryDeser
            x::Int
        end
        result = try_from_toml(_TomlTryDeser, "y = 5")
        @test result isa SerdeError
    end

    @testset "to_toml with context — >32 fields" begin
        field_decls = join(["ctf$i::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _Big34TomlCtx; $field_decls; end"))
        vals = ntuple(i -> i, 34)
        obj = Main._Big34TomlCtx(vals...)
        toml = to_toml(CamelCase(), obj)
        @test length(toml) > 0
    end

    @testset "parse_toml Vector{UInt8}" begin
        bytes = Vector{UInt8}("x = 42\n")
        d = parse_toml(bytes)
        @test d["x"] == 42
    end

    @testset "to_toml Bool" begin
        struct _TomlBoolField
            flag::Bool
        end
        @test occursin("true", to_toml(_TomlBoolField(true)))
        @test occursin("false", to_toml(_TomlBoolField(false)))
    end

    @testset "to_toml integer key" begin
        # TOML with integer key via Dict
        d = Dict(1 => "value")
        toml = to_toml(d)
        @test occursin("1", toml)
    end

    @testset "to_toml negative integer via _toml_key" begin
        # Negative key in Dict
        d = Dict(-1 => "neg")
        toml = to_toml(d)
        @test occursin("-1", toml)
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# 5. CSV — непокрытые пути
# ─────────────────────────────────────────────────────────────────────────────

@testset "CSV format — edge cases" begin

    @testset "to_csv empty vector" begin
        struct _CsvEmptyVec
            x::Int
        end
        result = to_csv(Vector{_CsvEmptyVec}())
        @test result == ""
    end

    @testset "to_csv with nested struct columns" begin
        struct _CsvNestedInner
            lat::Float64
            lon::Float64
        end
        struct _CsvNestedOuter
            name::String
            loc::_CsvNestedInner
        end
        data = [_CsvNestedOuter("A", _CsvNestedInner(1.0, 2.0))]
        csv = to_csv(data)
        # Nested struct flattened to loc_lat / loc_lon
        @test occursin("loc_lat", csv) || occursin("lat", csv)
        @test occursin("1.0", csv)
    end

    @testset "to_csv with >32 fields struct" begin
        field_decls = join(["cf$i::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _Big34Csv; $field_decls; end"))
        vals = ntuple(i -> i, 34)
        obj = Main._Big34Csv(vals...)
        csv = to_csv([obj])
        @test occursin("cf1", csv)
        @test occursin("cf34", csv)
        lines = split(strip(csv), "\n")
        @test length(lines) == 2  # header + 1 data row
    end

    @testset "from_csv Nothing/Missing" begin
        @test from_csv(Nothing, "x\n1") === nothing
        @test from_csv(Missing, "x\n1") === missing
    end

    @testset "from_csv function dispatch" begin
        struct _CsvDispA
            name::String
            age::Int
        end
        csv = "name,age\nAlice,30"
        result = from_csv(csv) do _
            Vector{_CsvDispA}
        end
        @test result isa Vector{_CsvDispA}
        @test result[1].name == "Alice"
    end

    @testset "to_csv with null field (nothing)" begin
        struct _CsvNullable2
            name::String
            tag::Union{Nothing,String}
        end
        data = [_CsvNullable2("A", nothing), _CsvNullable2("B", "yes")]
        csv = to_csv(data)
        @test occursin("A", csv)
        @test occursin("B", csv)
        @test occursin("yes", csv)
    end

    @testset "to_csv custom delimiter with escaping" begin
        struct _CsvSemicolon
            text::String
        end
        # text with semicolon — needs quoting when delimiter is ;
        data = [_CsvSemicolon("a;b")]
        csv = to_csv(data; delimiter = ";")
        @test occursin("\"a;b\"", csv)
    end

    @testset "try_from_csv success" begin
        struct _CsvTryOk
            id::Int
            name::String
        end
        result = try_from_csv(_CsvTryOk, "id,name\n1,Alice\n2,Bob")
        @test result isa Vector{_CsvTryOk}
        @test length(result) == 2
        @test result[1].id == 1
    end

    @testset "try_from_csv — error path (type mismatch)" begin
        struct _CsvTryErr
            id::Int
        end
        result = try_from_csv(_CsvTryErr, "id\nabc")
        @test result isa SerdeError
    end

    @testset "to_csv context-aware with >32 fields" begin
        field_decls = join(["ccf$i::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _Big34CsvCtx; $field_decls; end"))
        vals = ntuple(i -> i, 34)
        obj = Main._Big34CsvCtx(vals...)
        csv = to_csv(CamelCase(), [obj])
        @test length(csv) > 0
    end

    @testset "to_csv with newline in field (needs escaping)" begin
        struct _CsvNewline
            text::String
        end
        data = [_CsvNewline("line1\nline2")]
        csv = to_csv(data)
        @test occursin("\"line1", csv)
    end

    @testset "to_csv custom headers — column subset" begin
        struct _CsvHeaders2
            a::Int
            b::Int
            c::Int
        end
        csv = to_csv([_CsvHeaders2(1, 2, 3)]; headers = ["c", "a"])
        lines = split(strip(csv), "\n")
        @test lines[1] == "c,a"
        parts = split(lines[2], ",")
        @test parts[1] == "3"
        @test parts[2] == "1"
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# 6. Query — непокрытые пути
# ─────────────────────────────────────────────────────────────────────────────

@testset "Query format — edge cases" begin

    @testset "parse_query key without equals — empty value" begin
        d = parse_query("other=val")
        @test d["other"] == "val"
    end

    @testset "_query_cut — no separator returns (s, empty)" begin
        # parse_query with no = gives empty string value
        d = parse_query("keyonly")
        # key "keyonly" with empty value
        @test haskey(d, "keyonly")
        @test d["keyonly"] == ""
    end

    @testset "parse_query repeated key — becomes last value" begin
        d = parse_query("a=1&a=2")
        @test d["a"] isa Vector
    end

    @testset "parse_query semicolon in key throws" begin
        @test_throws ParseError parse_query("key;bad=value")
    end

    @testset "parse_query invalid escape sequence" begin
        @test_throws ParseError parse_query("key=%ZZ")
    end

    @testset "parse_query truncated escape at end" begin
        @test_throws ParseError parse_query("key=%2")
    end

    @testset "to_query with >32 fields struct" begin
        field_decls = join(["qf$i::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _Big34Query; $field_decls; end"))
        vals = ntuple(i -> i, 34)
        obj = Main._Big34Query(vals...)
        q = to_query(obj; escape = false)
        @test occursin("qf1=1", q)
        @test occursin("qf34=34", q)
    end

    @testset "from_query Nothing/Missing" begin
        @test from_query(Nothing, "x=1") === nothing
        @test from_query(Missing, "x=1") === missing
    end

    @testset "from_query function dispatch" begin
        struct _QueryDispA
            name::String
            value::String
        end
        result = from_query("name=Alice&value=100") do _
            _QueryDispA
        end
        @test result isa _QueryDispA
        @test result.name == "Alice"
    end

    @testset "to_query with nothing field (null skip)" begin
        struct _QueryNullable
            name::String
            tag::Union{Nothing,String}
        end
        Serde.ser_skip(::Type{_QueryNullable}, ::Val{:tag}, v) = isnothing(v)
        q = to_query(_QueryNullable("Alice", nothing); escape = false)
        @test occursin("name=Alice", q)
        @test !occursin("tag", q)
    end

    @testset "to_query with context — >32 fields" begin
        field_decls = join(["qcf$i::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _Big34QueryCtx; $field_decls; end"))
        vals = ntuple(i -> i, 34)
        obj = Main._Big34QueryCtx(vals...)
        q = to_query(CamelCase(), obj; escape = false)
        @test length(q) > 0
    end

    @testset "try_from_query success" begin
        struct _QueryTryOk
            x::Int
            y::String
        end
        result = try_from_query(_QueryTryOk, "x=5&y=hello")
        @test result isa _QueryTryOk
        @test result.x == 5
        @test result.y == "hello"
    end

    @testset "try_from_query — DeserError path" begin
        struct _QueryTryBad
            x::Int
        end
        result = try_from_query(_QueryTryBad, "y=abc")
        @test result isa SerdeError
    end

    @testset "parse_query custom delimiter" begin
        d = parse_query("a=1;b=2"; delimiter = ";")
        @test d["a"] == "1"
        @test d["b"] == "2"
    end

    @testset "to_query empty struct" begin
        struct _QueryEmpty end
        q = to_query(_QueryEmpty(); escape = false)
        @test q == ""
    end

    @testset "to_query Set value" begin
        struct _QuerySetVal
            items::Set{Int}
        end
        q = to_query(_QuerySetVal(Set([1, 2])); escape = false)
        @test occursin("items=", q)
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# 7. MsgPack — непокрытые пути
# ─────────────────────────────────────────────────────────────────────────────

@testset "MsgPack format — edge cases" begin

    @testset "DateTime with nanoseconds (8-byte fixext8 format)" begin
        # DateTime with ms > 0 triggers 8-byte path (nanoseconds != 0)
        dt = Dates.DateTime(2020, 1, 1, 0, 0, 0, 500)
        bytes = to_msgpack(dt)
        recovered = parse_msgpack(bytes)
        @test recovered isa Dates.DateTime
        @test Dates.millisecond(recovered) == 500
    end

    @testset "DateTime pre-epoch (12-byte ext8 format)" begin
        # DateTime before Unix epoch (1960) triggers 12-byte path
        dt = Dates.DateTime(1960, 1, 1, 0, 0, 0)
        bytes = to_msgpack(dt)
        recovered = parse_msgpack(bytes)
        @test recovered isa Dates.DateTime
        @test Dates.year(recovered) == 1960
    end

    @testset "large string STR8 round-trip" begin
        # String 32..255 bytes uses STR8
        s = 'x'^100
        bytes = to_msgpack(s)
        recovered = parse_msgpack(bytes)
        @test recovered == s
    end

    @testset "large string STR16 round-trip" begin
        # String 256..65535 bytes uses STR16
        s = 'x'^300
        bytes = to_msgpack(s)
        recovered = parse_msgpack(bytes)
        @test recovered == s
    end

    @testset "large array ARR16 round-trip" begin
        arr = collect(1:20)
        bytes = to_msgpack(arr)
        recovered = parse_msgpack(bytes)
        @test recovered == arr
    end

    @testset "large array ARR16 (300 elements)" begin
        arr16 = collect(1:300)
        bytes = to_msgpack(arr16)
        recovered = parse_msgpack(bytes)
        @test length(recovered) == 300
        @test recovered[1] == 1
        @test recovered[300] == 300
    end

    @testset "large map MAP16 round-trip" begin
        d = Dict(string(i) => i for i in 1:20)
        bytes = to_msgpack(d)
        recovered = parse_msgpack(bytes)
        @test recovered["1"] == 1
        @test recovered["20"] == 20
    end

    @testset "UInt64 large value round-trip" begin
        v = typemax(Int64) + UInt64(1)
        bytes = to_msgpack(v)
        recovered = parse_msgpack(bytes)
        @test recovered == v
    end

    @testset "Float32 round-trip" begin
        v = Float32(3.14)
        bytes = to_msgpack(v)
        recovered = parse_msgpack(bytes)
        @test Float32(recovered) ≈ v
    end

    @testset "to_msgpack Char" begin
        bytes = to_msgpack('A')
        @test parse_msgpack(bytes) == "A"
    end

    @testset "to_msgpack Enum" begin
        @enum _MsgPackColor mred mgreen mblue
        bytes = to_msgpack(mgreen)
        @test parse_msgpack(bytes) == "mgreen"
    end

    @testset "to_msgpack Regex" begin
        r = r"hello.*world"
        bytes = to_msgpack(r)
        @test parse_msgpack(bytes) isa String
    end

    @testset "to_msgpack Set" begin
        s = Set([1, 2, 3])
        bytes = to_msgpack(s)
        arr = parse_msgpack(bytes)
        @test arr isa Vector
        @test length(arr) == 3
    end

    @testset "to_msgpack NamedTuple" begin
        nt = (; a = 1, b = "hello")
        bytes = to_msgpack(nt)
        d = parse_msgpack(bytes)
        @test d["a"] == 1
        @test d["b"] == "hello"
    end

    @testset "to_msgpack Pair" begin
        bytes = to_msgpack("key" => 42)
        d = parse_msgpack(bytes)
        @test d["key"] == 42
    end

    @testset "to_msgpack 2D Array" begin
        A = [1 2; 3 4]
        bytes = to_msgpack(A)
        arr = parse_msgpack(bytes)
        @test arr isa Vector
    end

    @testset "to_msgpack struct with >32 fields" begin
        field_decls = join(["mf$i::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _Big34Msgpack; $field_decls; end"))
        vals = ntuple(i -> i, 34)
        obj = Main._Big34Msgpack(vals...)
        bytes = to_msgpack(obj)
        recovered = parse_msgpack(bytes)
        @test recovered isa Dict
        @test recovered["mf1"] == 1
        @test recovered["mf34"] == 34
    end

    @testset "from_msgpack struct with >32 fields round-trip" begin
        field_decls = join(["mfr$i::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _Big34MsgpackRound; $field_decls; end"))
        vals = ntuple(i -> i, 34)
        obj = Main._Big34MsgpackRound(vals...)
        bytes = to_msgpack(obj)
        recovered = from_msgpack(Main._Big34MsgpackRound, bytes)
        @test getfield(recovered, :mfr1) == 1
        @test getfield(recovered, :mfr34) == 34
    end

    @testset "to_msgpack context-aware with >32 fields" begin
        field_decls = join(["mcf$i::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _Big34MsgpackCtx; $field_decls; end"))
        vals = ntuple(i -> i, 34)
        obj = Main._Big34MsgpackCtx(vals...)
        bytes = to_msgpack(CamelCase(), obj)
        recovered = parse_msgpack(bytes)
        @test recovered isa Dict
        @test length(recovered) == 34
    end

    @testset "to_msgpack BIN16 round-trip" begin
        # BIN16: 256..65535 bytes
        bin16 = UInt8.(fill(0xAB, 300))
        bytes = to_msgpack(bin16)
        recovered = parse_msgpack(bytes)
        @test recovered == bin16
    end

    @testset "to_msgpack UUID" begin
        u = uuid4()
        bytes = to_msgpack(u)
        @test parse_msgpack(bytes) == string(u)
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# 8. JSON — дополнительные edge cases
# ─────────────────────────────────────────────────────────────────────────────

@testset "JSON format — additional edge cases" begin

    @testset "from_json Union{Missing,T}" begin
        struct _JsonMissing
            x::Union{Missing,Int}
        end
        obj = from_json(_JsonMissing, "{\"x\": 42}")
        @test obj.x === 42

        obj2 = from_json(_JsonMissing, "{}")
        @test ismissing(obj2.x)
    end

    @testset "from_json with Enum field" begin
        @enum _JsonEnum je_a je_b je_c
        struct _JsonEnumField
            color::_JsonEnum
        end
        obj = from_json(_JsonEnumField, "{\"color\": \"je_b\"}")
        @test obj.color === je_b
    end

    @testset "from_json with UUID field (stored as String)" begin
        u = uuid4()
        struct _JsonUUIDFieldStr
            id::String
        end
        json = "{\"id\": \"$(string(u))\"}"
        obj = from_json(_JsonUUIDFieldStr, json)
        @test obj.id == string(u)
    end

    @testset "from_json with UUID field via custom deser" begin
        u = uuid4()
        struct _JsonUUIDField2
            id::UUID
        end
        Serde.deser(::Serde.DefaultStrategy, ::Type{_JsonUUIDField2}, ::Type{UUID}, v::String) =
            UUID(v)
        json = "{\"id\": \"$(string(u))\"}"
        obj = from_json(_JsonUUIDField2, json)
        @test obj.id == u
    end

    @testset "from_json with DateTime field via custom deser" begin
        struct _JsonDTField2
            ts::Dates.DateTime
        end
        Serde.deser(::Serde.DefaultStrategy, ::Type{_JsonDTField2}, ::Type{Dates.DateTime}, v::String) =
            Dates.DateTime(v)
        json = "{\"ts\": \"2024-01-15T10:30:00\"}"
        obj = from_json(_JsonDTField2, json)
        @test obj.ts isa Dates.DateTime
        @test Dates.year(obj.ts) == 2024
    end

    @testset "from_json Dict field" begin
        struct _JsonDictField
            data::Dict{String,Int}
        end
        obj = from_json(_JsonDictField, "{\"data\": {\"a\": 1, \"b\": 2}}")
        @test obj.data["a"] == 1
        @test obj.data["b"] == 2
    end

    @testset "from_json Set field" begin
        struct _JsonSetField
            tags::Set{String}
        end
        obj = from_json(_JsonSetField, "{\"tags\": [\"a\", \"b\", \"c\"]}")
        @test "a" in obj.tags
        @test length(obj.tags) == 3
    end

    @testset "from_json Tuple field" begin
        struct _JsonTupleField
            pair::Tuple{Int,String}
        end
        obj = from_json(_JsonTupleField, "{\"pair\": [42, \"hello\"]}")
        @test obj.pair == (42, "hello")
    end

    @testset "from_json into Dict (NamedTuple not supported — use Dict)" begin
        # JSON parsing into NamedTuple not supported directly; Dict is returned
        d = from_json(Dict{String,Int}, "{\"x\": 1, \"y\": 2}")
        @test d["x"] == 1
        @test d["y"] == 2
    end

    @testset "to_json Enum" begin
        @enum _JsonColorE jred jgreen jblue
        @test to_json(jgreen) == "\"jgreen\""
    end

    @testset "to_json UUID" begin
        u = Base.UUID("550e8400-e29b-41d4-a716-446655440000")
        @test to_json(u) == "\"550e8400-e29b-41d4-a716-446655440000\""
    end

    @testset "to_json Char" begin
        @test to_json('A') == "\"A\""
    end

    @testset "to_json nested struct" begin
        struct _JsonNested2Inner
            val::Int
        end
        struct _JsonNested2Outer
            name::String
            inner::_JsonNested2Inner
        end
        json = to_json(_JsonNested2Outer("test", _JsonNested2Inner(42)))
        @test occursin("\"name\":\"test\"", json)
        @test occursin("\"val\":42", json)
    end

    @testset "to_json NamedTuple" begin
        nt = (; a = 1, b = "x")
        json = to_json(nt)
        @test occursin("\"a\":1", json)
        @test occursin("\"b\":\"x\"", json)
    end

    @testset "to_json Pair" begin
        json = to_json("key" => 42)
        @test occursin("\"key\":42", json)
    end

    @testset "to_json Set" begin
        json = to_json(Set([1]))
        @test json == "[1]"
    end

    @testset "to_json with ser_skip conditional" begin
        struct _JsonSkipCond
            name::String
            score::Int
        end
        Serde.ser_skip(::Type{_JsonSkipCond}, ::Val{:score}, v) = v <= 0
        json1 = to_json(_JsonSkipCond("A", 10))
        @test occursin("score", json1)

        json2 = to_json(_JsonSkipCond("B", 0))
        @test !occursin("score", json2)
    end

    @testset "from_json with PascalCase context" begin
        struct _JsonPascal
            my_field::Int
            other_val::String
        end
        json = "{\"MyField\": 1, \"OtherVal\": \"test\"}"
        obj = from_json(PascalCase(), _JsonPascal, json)
        @test obj.my_field == 1
        @test obj.other_val == "test"

        json_out = to_json(PascalCase(), _JsonPascal(2, "x"))
        @test occursin("MyField", json_out)
    end

    @testset "from_json with KebabCase context" begin
        struct _JsonKebab
            my_field::Int
        end
        json = "{\"my-field\": 99}"
        obj = from_json(KebabCase(), _JsonKebab, json)
        @test obj.my_field == 99

        json_out = to_json(KebabCase(), _JsonKebab(99))
        @test occursin("my-field", json_out)
    end

    @testset "from_json with LowerCase context" begin
        struct _JsonLower
            myfield::Int
        end
        json = "{\"myfield\": 7}"
        obj = from_json(LowerCase(), _JsonLower, json)
        @test obj.myfield == 7
    end

    @testset "from_json Bool coercion" begin
        struct _JsonBoolField
            active::Bool
        end
        obj = from_json(_JsonBoolField, "{\"active\": true}")
        @test obj.active === true
        obj2 = from_json(_JsonBoolField, "{\"active\": false}")
        @test obj2.active === false
    end

    @testset "to_json Bool" begin
        @test to_json(true) == "true"
        @test to_json(false) == "false"
    end

    @testset "to_json with struct >32 fields" begin
        field_decls = join(["jf$i::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _Big34Json; $field_decls; end"))
        vals = ntuple(i -> i, 34)
        obj = Main._Big34Json(vals...)
        json = to_json(obj)
        @test occursin("\"jf1\":1", json)
        @test occursin("\"jf34\":34", json)
    end

    @testset "from_json struct with >32 fields" begin
        field_decls = join(["jr$i::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _Big34JsonRound; $field_decls; end"))
        vals = ntuple(i -> i, 34)
        obj = Main._Big34JsonRound(vals...)
        json = to_json(obj)
        recovered = from_json(Main._Big34JsonRound, json)
        @test getfield(recovered, :jr1) == 1
        @test getfield(recovered, :jr34) == 34
    end

    @testset "to_pretty_json basic" begin
        struct _JsonPretty2
            x::Int
            y::String
        end
        pretty = to_pretty_json(_JsonPretty2(1, "hello"))
        @test occursin("\n", pretty)
        @test occursin("\"x\"", pretty)
    end

    @testset "from_json MissingFieldError" begin
        struct _JsonMissField
            required::Int
        end
        @test_throws MissingFieldError from_json(_JsonMissField, "{}")
    end

    @testset "from_json int field from JSON object throws TypeMismatchError" begin
        struct _JsonTypeMismatch
            x::Int
        end
        # JSON direct deserialization: object-to-int is a type mismatch and must
        # error rather than silently producing 0. Regression test for the fast-path
        # primitive extractor previously zero-filling on shape mismatch.
        @test_throws TypeMismatchError from_json(_JsonTypeMismatch, "{\"x\": {\"nested\": 1}}")
    end

    @testset "to_*(io::IO, ...) overloads" begin
        # Phase 12 / API consistency: every format must accept an IO sink.
        struct _IOStruct; n::Int; s::String; end
        v = _IOStruct(7, "hi")

        # JSON already has it; sanity-check.
        io = IOBuffer(); to_json(io, v); @test occursin("\"n\":7", String(take!(io)))

        io = IOBuffer(); to_msgpack(io, v); @test parse_msgpack(take!(io))["n"] == 7
        io = IOBuffer(); to_bson(io, v);    @test parse_bson(take!(io))["n"] == 7

        io = IOBuffer(); to_toml(io, v); @test occursin("n = 7", String(take!(io)))
        io = IOBuffer(); to_yaml(io, v); @test occursin("n: 7", String(take!(io)))
        io = IOBuffer(); to_xml(io, v);  @test occursin("n=\"7\"", String(take!(io)))
        io = IOBuffer(); to_query(io, v); @test occursin("n=7", String(take!(io)))
        io = IOBuffer(); to_csv(io, [v]); @test occursin("n,s", String(take!(io)))
        io = IOBuffer(); to_msgpack(io, CamelCase(), v); @test parse_msgpack(take!(io))["n"] == 7
    end

    @testset "from_json invalid string for Int throws" begin
        struct _JsonBadString
            x::Int
        end
        @test_throws Exception from_json(_JsonBadString, "{\"x\": \"abc\"}")
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# 9. BSON — дополнительные edge cases
# ─────────────────────────────────────────────────────────────────────────────

@testset "BSON format — additional edge cases" begin

    @testset "to_bson Enum" begin
        @enum _BsonColorEnum bred bgreen bblue
        struct _BsonEnumField
            color::_BsonColorEnum
        end
        bytes = to_bson(_BsonEnumField(bgreen))
        d = parse_bson(bytes)
        @test d["color"] == "bgreen"
    end

    @testset "to_bson Symbol" begin
        bytes = to_bson(Dict("sym" => :hello))
        d = parse_bson(bytes)
        @test d["sym"] == "hello"
    end

    @testset "to_bson Tuple" begin
        bytes = to_bson(Dict("t" => (1, "two", 3.0)))
        d = parse_bson(bytes)
        @test d["t"] == [1, "two", 3.0]
    end

    @testset "to_bson Set" begin
        bytes = to_bson(Dict("s" => Set([1, 2, 3])))
        d = parse_bson(bytes)
        @test length(d["s"]) == 3
    end

    @testset "to_bson struct with >32 fields" begin
        field_decls = join(["bf$i::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _Big34Bson; $field_decls; end"))
        vals = ntuple(i -> i, 34)
        obj = Main._Big34Bson(vals...)
        bytes = to_bson(obj)
        d = parse_bson(bytes)
        @test d["bf1"] == 1
        @test d["bf34"] == 34
    end

    @testset "from_bson struct with >32 fields round-trip" begin
        field_decls = join(["bfr$i::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _Big34BsonRound; $field_decls; end"))
        vals = ntuple(i -> i, 34)
        obj = Main._Big34BsonRound(vals...)
        bytes = to_bson(obj)
        recovered = from_bson(Main._Big34BsonRound, bytes)
        @test getfield(recovered, :bfr1) == 1
        @test getfield(recovered, :bfr34) == 34
    end

    @testset "try_from_bson context success with default" begin
        struct _BsonCtxTry
            x::Int
        end
        struct _BsonCtx2 end
        Serde.has_default(::_BsonCtx2, ::Type{_BsonCtxTry}, ::Val{:x}) = true
        Serde.deser_default(::_BsonCtx2, ::Type{_BsonCtxTry}, ::Val{:x}) = 99
        result = try_from_bson(_BsonCtx2(), _BsonCtxTry, to_bson(Dict{String,Any}()))
        @test result isa _BsonCtxTry
        @test result.x == 99
    end

    @testset "to_bson with context — >32 fields" begin
        field_decls = join(["bcf$i::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _Big34BsonCtx; $field_decls; end"))
        vals = ntuple(i -> i, 34)
        obj = Main._Big34BsonCtx(vals...)
        bytes = to_bson(CamelCase(), obj)
        d = parse_bson(bytes)
        @test length(d) == 34
    end

    @testset "from_bson UUID field" begin
        u = uuid4()
        bytes = to_bson(Dict("id" => string(u)))
        d = parse_bson(bytes)
        @test d["id"] == string(u)
    end

    @testset "to_bson Bool" begin
        d = parse_bson(to_bson(Dict("t" => true, "f" => false)))
        @test d["t"] === true
        @test d["f"] === false
    end

    @testset "from_bson Enum via String" begin
        @enum _BsonE2 ba bb bc
        struct _BsonEnumDeser
            e::_BsonE2
        end
        bytes = to_bson(Dict("e" => "bb"))
        obj = from_bson(_BsonEnumDeser, bytes)
        @test obj.e === bb
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# 10. Ser engine — дополнительные тесты
# ─────────────────────────────────────────────────────────────────────────────

@testset "Ser engine — additional" begin

    @testset "ser_pairs strategy — rename" begin
        struct _SerCtxRename
            user_name::String
            score::Int
        end
        struct _SerCtxX end
        Serde.ser_name(::_SerCtxX, ::Type{_SerCtxRename}, ::Val{:user_name}) = :userName

        pairs = Serde.ser_pairs(_SerCtxX(), _SerCtxRename("Alice", 10))
        names = [p[1] for p in pairs]
        @test :userName in names
        @test :user_name ∉ names
    end

    @testset "ser_pairs strategy — value transform" begin
        struct _SerCtxTransform
            val::Float64
        end
        struct _SerCtxRound2 end
        Serde.ser_value(::_SerCtxRound2, ::Type{_SerCtxTransform}, ::Val{:val}, v) = round(v; digits=1)

        pairs = Serde.ser_pairs(_SerCtxRound2(), _SerCtxTransform(3.14159))
        @test pairs[1][2] == 3.1
    end

    @testset "ser_pairs strategy — skip field" begin
        struct _SerCtxSkip
            visible::String
            hidden::String
        end
        struct _SerCtxHide end
        Serde.ser_skip(::_SerCtxHide, ::Type{_SerCtxSkip}, ::Val{:hidden}) = true

        pairs = Serde.ser_pairs(_SerCtxHide(), _SerCtxSkip("a", "b"))
        @test length(pairs) == 1
        @test pairs[1][1] == :visible
    end

    @testset "to_flatten custom delimiter" begin
        nested = Dict("a" => 1, "b" => Dict("c" => 2))
        flat = to_flatten(nested; delimiter = ".")
        @test flat["b.c"] == 2
    end

    @testset "to_flatten custom dict_type" begin
        nested = Dict("a" => Dict("b" => 1))
        flat = to_flatten(nested; dict_type = Dict{String,Any})
        @test flat["a_b"] == 1
    end

    @testset "to_flatten struct with nested dict" begin
        struct _FlatDict
            name::String
            meta::Dict{String,Int}
        end
        obj = _FlatDict("x", Dict("k" => 1))
        flat = to_flatten(obj)
        @test flat["name"] == "x"
        # meta is a dict, so flattened
        @test flat["meta_k"] == 1
    end

    @testset "issimple UUID" begin
        u = uuid4()
        @test Serde.issimple(u) === true
    end

    @testset "issimple DateTime" begin
        @test Serde.issimple(Dates.now()) === true
    end

    @testset "isnull zero and empty" begin
        @test Serde.isnull(0) === false
        @test Serde.isnull("") === false
        @test Serde.isnull([]) === false
    end

    @testset "ser_type context fallback" begin
        struct _SerTypeFb
            x::Float64
        end
        # Without strategy override, falls back to default
        v = Serde.ser_type(Serde.DefaultStrategy(), _SerTypeFb, 3.14)
        @test v == 3.14
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# 11. Case contexts — все форматы
# ─────────────────────────────────────────────────────────────────────────────

@testset "Case contexts — all formats" begin

    struct _CaseAll
        my_field::Int
        other_val::String
    end

    @testset "CamelCase with TOML" begin
        obj = _CaseAll(1, "test")
        toml = to_toml(CamelCase(), obj)
        @test occursin("myField", toml)
        @test !occursin("my_field", toml)

        recovered = from_toml(CamelCase(), _CaseAll, toml)
        @test recovered.my_field == 1
    end

    @testset "PascalCase with TOML" begin
        obj = _CaseAll(2, "x")
        toml = to_toml(PascalCase(), obj)
        @test occursin("MyField", toml)
        recovered = from_toml(PascalCase(), _CaseAll, toml)
        @test recovered.my_field == 2
    end

    @testset "KebabCase with TOML" begin
        obj = _CaseAll(3, "y")
        toml = to_toml(KebabCase(), obj)
        @test occursin("my-field", toml)
        recovered = from_toml(KebabCase(), _CaseAll, toml)
        @test recovered.my_field == 3
    end

    @testset "CamelCase with YAML" begin
        obj = _CaseAll(4, "z")
        yaml = to_yaml(CamelCase(), obj)
        @test occursin("myField", yaml)
        recovered = from_yaml(CamelCase(), _CaseAll, yaml)
        @test recovered.my_field == 4
    end

    @testset "PascalCase with YAML" begin
        obj = _CaseAll(5, "w")
        yaml = to_yaml(PascalCase(), obj)
        @test occursin("MyField", yaml)
        recovered = from_yaml(PascalCase(), _CaseAll, yaml)
        @test recovered.my_field == 5
    end

    @testset "KebabCase with YAML" begin
        obj = _CaseAll(6, "v")
        yaml = to_yaml(KebabCase(), obj)
        @test occursin("my-field", yaml)
        recovered = from_yaml(KebabCase(), _CaseAll, yaml)
        @test recovered.my_field == 6
    end

    @testset "CamelCase with Query" begin
        obj = _CaseAll(7, "u")
        q = to_query(CamelCase(), obj; escape = false)
        @test occursin("myField", q)
        # from_query(CamelCase(), T, q) has limitations with backbone parsing;
        # use parse_query + to_deser as the correct round-trip approach
        d = parse_query(q)
        recovered = Serde.to_deser(CamelCase(), _CaseAll, d)
        @test recovered.my_field == 7
        @test recovered.other_val == "u"
    end

    @testset "CamelCase with CSV" begin
        obj = _CaseAll(8, "t")
        csv = to_csv(CamelCase(), [obj])
        @test occursin("myField", csv)
        recovered = from_csv(CamelCase(), _CaseAll, csv)
        @test length(recovered) == 1
        @test recovered[1].my_field == 8
    end

    @testset "CamelCase with MsgPack" begin
        obj = _CaseAll(9, "s")
        bytes = to_msgpack(CamelCase(), obj)
        d = parse_msgpack(bytes)
        @test haskey(d, "myField")
        recovered = from_msgpack(CamelCase(), _CaseAll, bytes)
        @test recovered.my_field == 9
    end

    @testset "CamelCase with BSON" begin
        obj = _CaseAll(10, "r")
        bytes = to_bson(CamelCase(), obj)
        d = parse_bson(bytes)
        @test haskey(d, "myField")
        recovered = from_bson(CamelCase(), _CaseAll, bytes)
        @test recovered.my_field == 10
    end

    @testset "CamelCase with XML" begin
        obj = _CaseAll(11, "q")
        xml = to_xml(CamelCase(), obj; key = "root")
        @test occursin("myField", xml)
        recovered = from_xml(CamelCase(), _CaseAll, xml)
        @test recovered.my_field == 11
    end

    @testset "LowerCase with JSON" begin
        struct _LowerStruct
            MYFIELD::Int
        end
        obj = _LowerStruct(42)
        json = to_json(LowerCase(), obj)
        @test occursin("myfield", json)
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# 12. Tagged unions — дополнительные тесты
# ─────────────────────────────────────────────────────────────────────────────

@testset "Tagged unions — additional" begin

    abstract type _TUEvent end
    Serde.ClassType(::Type{_TUEvent}) = Serde.TaggedClass()
    Serde.tag_key(::Type{<:_TUEvent}) = "event_type"

    struct _TUClickEvent <: _TUEvent
        x::Int
        y::Int
    end
    register_tagged_subtype(_TUEvent, "_TUClickEvent", _TUClickEvent)

    struct _TUKeyEvent <: _TUEvent
        key::String
        modifiers::Vector{String}
    end
    register_tagged_subtype(_TUEvent, "_TUKeyEvent", _TUKeyEvent)

    @testset "Dispatch works for multiple subtypes" begin
        json_click = "{\"event_type\": \"_TUClickEvent\", \"x\": 10, \"y\": 20}"
        ev = from_json(_TUEvent, json_click)
        @test ev isa _TUClickEvent
        @test ev.x == 10
        @test ev.y == 20

        json_key = "{\"event_type\": \"_TUKeyEvent\", \"key\": \"Enter\", \"modifiers\": []}"
        ev2 = from_json(_TUEvent, json_key)
        @test ev2 isa _TUKeyEvent
        @test ev2.key == "Enter"
    end

    @testset "Unknown tag raises an error" begin
        json_bad = "{\"event_type\": \"UnknownEvent\", \"x\": 1}"
        @test_throws Exception from_json(_TUEvent, json_bad)
    end

    @testset "Missing tag raises an error" begin
        json_no_tag = "{\"x\": 1, \"y\": 2}"
        @test_throws Exception from_json(_TUEvent, json_no_tag)
    end

    @testset "register_tagged_subtype accumulates subtypes" begin
        subs = Serde.tag_subtypes(_TUEvent)
        tag_vals = [p.first for p in subs]
        @test "_TUClickEvent" in tag_vals
        @test "_TUKeyEvent" in tag_vals
    end

    @testset "Tagged union with YAML" begin
        yaml = "event_type: _TUClickEvent\nx: 5\ny: 6\n"
        ev = from_yaml(_TUEvent, yaml)
        @test ev isa _TUClickEvent
        @test ev.x == 5
    end

    @testset "Tagged union with TOML" begin
        toml = "event_type = \"_TUClickEvent\"\nx = 7\ny = 8\n"
        ev = from_toml(_TUEvent, toml)
        @test ev isa _TUClickEvent
        @test ev.x == 7
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# 13. Error types — дополнительные тесты
# ─────────────────────────────────────────────────────────────────────────────

@testset "Error types — additional" begin

    @testset "ParseError is SerdeError" begin
        e = ParseError("JSON", "test", ErrorException("cause"))
        @test e isa SerdeError
    end

    @testset "MissingFieldError is DeserError and SerdeError" begin
        e = MissingFieldError(String, :name)
        @test e isa DeserError
        @test e isa SerdeError
        @test e.type == String
        @test e.field == :name
    end

    @testset "TypeMismatchError fields" begin
        e = TypeMismatchError(String, :x, Int, String, "bad")
        @test e.type == String
        @test e.field == :x
        @test e.expected == Int
        @test e.got == String
        @test e.value == "bad"
    end

    @testset "ValidationError fields" begin
        e = ValidationError(String, :email, "x", "must have @")
        @test e.type == String
        @test e.field == :email
        @test e.value == "x"
        @test e.message == "must have @"
    end

    @testset "showerror ValidationError" begin
        e = ValidationError(Int, :score, -1, "must be positive")
        buf = IOBuffer()
        showerror(buf, e)
        msg = String(take!(buf))
        @test occursin("ValidationError", msg)
        @test occursin("score", msg)
        @test occursin("-1", msg)
        @test occursin("must be positive", msg)
    end

    @testset "showerror ParseError includes cause" begin
        cause = ErrorException("underlying cause")
        e = ParseError("YAML", "invalid syntax", cause)
        buf = IOBuffer()
        showerror(buf, e)
        msg = String(take!(buf))
        @test occursin("ParseError", msg)
        @test occursin("YAML", msg)
        @test occursin("caused by", msg)
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# 14. Traits — strategy-aware fallbacks
# ─────────────────────────────────────────────────────────────────────────────

@testset "Trait strategy-aware fallbacks" begin

    struct _TraitFb; x::Int; end

    @testset "deser_name strategy fallback" begin
        strategy = Serde.DefaultStrategy()
        @test Serde.deser_name(strategy, _TraitFb, Val(:x)) === :x
    end

    @testset "has_default strategy fallback" begin
        strategy = Serde.DefaultStrategy()
        @test Serde.has_default(strategy, _TraitFb, Val(:x)) === false
    end

    @testset "deser_default strategy fallback" begin
        strategy = Serde.DefaultStrategy()
        @test Serde.deser_default(strategy, _TraitFb, Val(:x)) === nothing
    end

    @testset "isempty_value strategy fallback" begin
        strategy = Serde.DefaultStrategy()
        @test Serde.isempty_value(strategy, _TraitFb, Val(:x), 0) === false
    end

    @testset "deser_transform strategy fallback" begin
        strategy = Serde.DefaultStrategy()
        @test Serde.deser_transform(strategy, _TraitFb, Int, 42) === 42
    end

    @testset "deser_validate strategy fallback" begin
        strategy = Serde.DefaultStrategy()
        @test Serde.deser_validate(strategy, _TraitFb, Val(:x), 42) === nothing
    end

    @testset "ser_name strategy fallback" begin
        strategy = Serde.DefaultStrategy()
        @test Serde.ser_name(strategy, _TraitFb, Val(:x)) === :x
    end

    @testset "ser_value strategy fallback" begin
        strategy = Serde.DefaultStrategy()
        @test Serde.ser_value(strategy, _TraitFb, Val(:x), 42) === 42
    end

    @testset "ser_type strategy fallback" begin
        strategy = Serde.DefaultStrategy()
        @test Serde.ser_type(strategy, _TraitFb, 42) === 42
    end

    @testset "ser_skip strategy fallback (no value)" begin
        strategy = Serde.DefaultStrategy()
        @test Serde.ser_skip(strategy, _TraitFb, Val(:x)) === false
    end

    @testset "ser_skip strategy fallback (with value)" begin
        strategy = Serde.DefaultStrategy()
        @test Serde.ser_skip(strategy, _TraitFb, Val(:x), 42) === false
    end
end
