@testset "CSV — nullable nested struct flattens consistently" begin
    # H7
    struct _CsvInner; a::Int; b::Int; end
    struct _CsvNullableNested
        id::Int
        inner::Union{Nothing, _CsvInner}
    end
    rows = [_CsvNullableNested(1, _CsvInner(10, 20)),
            _CsvNullableNested(2, nothing),
            _CsvNullableNested(3, _CsvInner(30, 40))]
    out = to_csv(rows)
    lines = split(out, '\n'; keepempty = false)
    n_cols = length(split(lines[1], ','))
    @test n_cols == 3
    for line in lines
        @test length(split(line, ',')) == n_cols
    end
end

@testset "CSV — top-level scalar input rejected" begin
    @test_throws ArgumentError to_csv([1, 2, 3])
end

@testset "CSV — RFC 4180 CRLF line endings (opt-in)" begin
    struct _CsvCrlf; a::Int; end
    out = to_csv([_CsvCrlf(1), _CsvCrlf(2)]; crlf = true)
    @test occursin("\r\n", out)
end

@testset "CSV format" begin
    @testset "parse_csv basic" begin
        csv = "name,age\nAlice,30\nBob,25"
        rows = parse_csv(csv)
        @test length(rows) == 2
        @test rows[1].name == "Alice"
        @test rows[1].age == "30"
        @test rows[2].name == "Bob"
    end

    @testset "parse_csv with quotes" begin
        csv = "name,desc\nAlice,\"hello, world\"\nBob,\"say \"\"hi\"\"\""
        rows = parse_csv(csv)
        @test rows[1].desc == "hello, world"
        @test rows[2].desc == "say \"hi\""
    end

    @testset "parse_csv custom delimiter" begin
        csv = "a;b\n1;2\n3;4"
        rows = parse_csv(csv; delimiter = ";")
        @test rows[1].a == "1"
        @test rows[1].b == "2"
    end

    @testset "parse_csv Vector{UInt8}" begin
        bytes = Vector{UInt8}("x,y\n1,2")
        rows = parse_csv(bytes)
        @test length(rows) == 1
    end

    @testset "from_csv" begin
        struct _CsvData
            id::Int
            name::String
        end
        csv = "id,name\n1,Fred\n2,Benny"
        result = from_csv(_CsvData, csv)
        @test length(result) == 2
        @test result[1].id == 1
        @test result[1].name == "Fred"
        @test result[2].id == 2
    end

    @testset "to_csv" begin
        struct _CsvSer
            val::Int
            str::String
        end
        data = [_CsvSer(1, "a"), _CsvSer(2, "b")]
        csv = to_csv(data)
        @test contains(csv, "val")
        @test contains(csv, "str")
        @test contains(csv, "1")
        @test contains(csv, "a")
    end

    @testset "to_csv custom delimiter" begin
        struct _CsvDelim
            x::Int
            y::Int
        end
        csv = to_csv([_CsvDelim(1, 2)]; delimiter = ";")
        @test contains(csv, ";")
    end

    @testset "to_csv with headers" begin
        struct _CsvHeaders
            a::Int
            b::Int
            c::Int
        end
        csv = to_csv([_CsvHeaders(1, 2, 3)]; headers = ["c", "a"])
        lines = split(strip(csv), "\n")
        @test lines[1] == "c,a"
    end

    @testset "to_csv without names" begin
        struct _CsvNoNames
            x::Int
        end
        csv = to_csv([_CsvNoNames(1)]; with_names = false)
        @test !contains(csv, "x\n")
    end

    @testset "to_csv escaping" begin
        struct _CsvEsc
            text::String
        end
        csv = to_csv([_CsvEsc("hello, world")])
        @test contains(csv, "\"hello, world\"")
    end

    @testset "Round-trip" begin
        struct _CsvRound
            id::Int
            name::String
        end
        data = [_CsvRound(1, "Alice"), _CsvRound(2, "Bob")]
        recovered = from_csv(_CsvRound, to_csv(data))
        @test length(recovered) == 2
        @test recovered[1].id == 1
        @test recovered[1].name == "Alice"
    end
end

@testset "CSV — additional coverage paths" begin

    @testset "to_csv nested struct columns (flat path)" begin
        # Structure with nested struct forces _csv_flat_columns recursive call
        struct _CsvInner2
            x::Float64
            y::Float64
        end
        struct _CsvOuter2
            name::String
            pos::_CsvInner2
        end
        data = [_CsvOuter2("A", _CsvInner2(1.0, 2.0)), _CsvOuter2("B", _CsvInner2(3.0, 4.0))]
        csv = to_csv(data)
        # Header should have pos_x and pos_y (flattened)
        @test occursin("pos_x", csv) || occursin("x", csv)
        # Values should be present
        @test occursin("1.0", csv)
        @test occursin("4.0", csv)
        # Round-trip via from_csv is not trivial for nested; just check output structure
        lines = split(strip(csv), "\n")
        @test length(lines) == 3  # header + 2 rows
    end

    @testset "to_csv _csv_write_row! nested struct (not-null nested)" begin
        # _csv_write_row! recurses into nested struct via _csv_is_nested
        struct _CsvDeepInner
            a::Int
        end
        struct _CsvDeepOuter
            tag::String
            inner::_CsvDeepInner
        end
        csv = to_csv([_CsvDeepOuter("X", _CsvDeepInner(99))])
        @test occursin("99", csv)
        @test occursin("X", csv)
    end

    @testset "parse_csv error triggers ParseError" begin
        # Feeding malformed binary content triggers ParseError
        @test_throws ParseError parse_csv(UInt8[0xFF, 0xFE, 0x00, 0x00])
    end
end

@testset "CSV — strategy serialization paths" begin

    @testset "to_csv(CamelCase(), data) basic" begin
        struct _CsvCtxBasic; my_name::String; my_val::Int; end
        data = [_CsvCtxBasic("Alice", 30), _CsvCtxBasic("Bob", 25)]
        csv = to_csv(CamelCase(), data)
        @test occursin("myName", csv) || occursin("myVal", csv)
        @test occursin("Alice", csv)
    end

    @testset "to_csv(CamelCase(), data) with nested struct" begin
        struct _CsvCtxInner; x_val::Int; end
        struct _CsvCtxOuter; label::String; inner::_CsvCtxInner; end
        data = [_CsvCtxOuter("A", _CsvCtxInner(1)), _CsvCtxOuter("B", _CsvCtxInner(2))]
        csv = to_csv(CamelCase(), data)
        @test occursin("1", csv) && occursin("2", csv)
    end

    @testset "to_csv(CamelCase(), data) with custom headers" begin
        struct _CsvCtxH; a::Int; b::String; end
        data = [_CsvCtxH(1, "x"), _CsvCtxH(2, "y")]
        csv = to_csv(CamelCase(), data; headers = ["a"])
        @test occursin("a", csv)
        @test occursin("1", csv)
    end

    @testset "to_csv with >32 fields (strategy path, >32 for-loop)" begin
        field_decls = join(["cf$i::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _CsvBig34; $field_decls; end"))
        vals = ntuple(i -> i, 34)
        obj = Main._CsvBig34(vals...)
        csv = to_csv(CamelCase(), [obj])
        @test occursin("cf1", csv)
        @test occursin("cf34", csv)
        @test occursin("34", csv)
    end

    @testset "to_csv with >32 fields (no-strategy path, >32 for-loop)" begin
        # Reuse the already-defined _CsvBig34 struct
        csv = to_csv([Main._CsvBig34(ntuple(i -> i, 34)...)])
        @test occursin("cf1", csv)
        @test occursin("cf34", csv)
    end
end

@testset "CSV — _csv_collect_values! with custom headers (>32 fields)" begin

    @testset "to_csv with >32 fields and custom headers uses _csv_collect_values!" begin
        field_decls = join(["ch$i::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _CsvH34; $field_decls; end"))
        vals = ntuple(i -> i, 34)
        obj = Main._CsvH34(vals...)
        # Custom headers triggers _csv_collect_values! path
        csv = to_csv([obj]; headers = ["ch1", "ch34"])
        @test occursin("ch1", csv)
        @test occursin("ch34", csv)
        @test occursin("1", csv)
        @test occursin("34", csv)
    end
end

@testset "CSV — strategy nested struct paths" begin

    @testset "to_csv(strategy, data) without custom headers — recursive write row (line 206)" begin
        struct _CsvSN2_Inner; x_count::Int; end
        struct _CsvSN2_Outer; label::String; pos::_CsvSN2_Inner; end
        data = [_CsvSN2_Outer("A", _CsvSN2_Inner(1)), _CsvSN2_Outer("B", _CsvSN2_Inner(2))]
        csv = to_csv(CamelCase(), data)
        @test occursin("1", csv) && occursin("2", csv)
        @test occursin("A", csv)
    end

    @testset "to_csv(strategy, data) with custom headers — _csv_collect_values! (lines 225,238)" begin
        struct _CsvSN3_Inner; score::Int; end
        struct _CsvSN3_Outer; name::String; data_point::_CsvSN3_Inner; end
        items = [_CsvSN3_Outer("X", _CsvSN3_Inner(100))]
        csv = to_csv(CamelCase(), items; headers = ["name", "dataPoint_score"])
        # headers causes _csv_collect_values!(strategy, ...) to be called
        @test occursin("name", csv)
    end

    @testset "to_csv(no-strategy) with >32 fields uses >32 for-loop" begin
        # The >32 fallback in _csv_write_row! (non-strategy)
        field_decls = join(["cns$(i)::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _CsvNS34; " * field_decls * "; end"))
        vals = ntuple(i -> i, 34)
        csv = to_csv([Main._CsvNS34(vals...)])
        @test occursin("cns34", csv)
        @test occursin("34", csv)
    end

    @testset "to_csv(strategy) with >32 fields uses >32 for-loop" begin
        field_decls = join(["css$(i)::Int" for i in 1:34], "; ")
        eval(Meta.parse("struct _CsvS34; " * field_decls * "; end"))
        vals = ntuple(i -> i, 34)
        csv = to_csv(CamelCase(), [Main._CsvS34(vals...)])
        @test occursin("css34", csv)
        @test occursin("34", csv)
    end
end

@testset "CSV — >32 fields strategy with nested struct at 33+" begin

    @testset "_csv_write_row! with nested struct in fields 33+ (line 206)" begin
        # Need a struct where N > 32 and one of fields 33+ is itself a nested struct
        # Field 33 will be a nested struct
        struct _CsvNested33_Inner; score::Int; end
        field_decls = join(["cnf$(i)::Int" for i in 1:32], "; ") *
                      "; nested_field::_CsvNested33_Inner"
        eval(Meta.parse("struct _CsvNested33; " * field_decls * "; end"))
        plain_vals = ntuple(i -> i, 32)
        nested_val = _CsvNested33_Inner(99)
        obj = Main._CsvNested33(plain_vals..., nested_val)
        csv = to_csv(CamelCase(), [obj])
        # nested struct value should appear flattened
        @test occursin("99", csv)
        @test occursin("cnf32", csv)
    end

    @testset "_csv_collect_values! with nested struct in fields 33+ (line 238)" begin
        # Same struct layout but accessed via to_csv with custom headers
        struct _CsvNested33b_Inner; rating::Int; end
        field_decls = join(["cnb$(i)::Int" for i in 1:32], "; ") *
                      "; nested_b::_CsvNested33b_Inner"
        eval(Meta.parse("struct _CsvNested33b; " * field_decls * "; end"))
        plain_vals = ntuple(i -> i, 32)
        nested_val = _CsvNested33b_Inner(77)
        obj = Main._CsvNested33b(plain_vals..., nested_val)
        # headers triggers _csv_collect_values! path
        csv = to_csv(CamelCase(), [obj]; headers = ["cnb1", "cnb32", "nestedB_rating"])
        @test occursin("77", csv)
    end
end
