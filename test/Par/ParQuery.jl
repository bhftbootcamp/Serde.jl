# Par/ParQuery

@testset verbose = true "ParQuery" begin
    @testset "Case №1: Cut" begin
        exp_objs = [
            ("fjNI5ScRd", "IVwGixm"),
            ("Y3",        "Km91rts"),
            ("Ii",        "4BAUXXO"),
            ("2t64A9G",   "590V"),
            ("gxNCeEoro", "pcqfxATYlH"),
            ("mIXYlMDF",  "e"),
            ("4BM0431qD", "w6R"),
            ("OEH",       "Qck"),
            ("d",         "yMJIx3"),
            ("GZ3L5vk6i", "1aDX29"),
            ("pX9dcpea",  "kR"),
            ("pOHTJR",    "8BAbdsoU5y"),
            ("mn1G",      "gX579nEK"),
            ("Kob",       "PdhsUEaj7"),
            ("HjweOODg",  "xB5WtFQlo"),
        ]
        for exp_obj in exp_objs
            exp_str = exp_obj[1] * "=" * exp_obj[2]
            @test Serde.ParQuery.cut(exp_str, "=") == exp_obj
        end
    end

    @testset "Case №2: Empty string" begin
        @test Serde.ParQuery.unescape("") == ""
    end

    @testset "Case №3: String without escaped characters" begin
        exp_strs = [
            "kc6VjhXv",
            "8fmbLDPn",
            "IUwx7",
            "HVEHkB3q",
            "R7JeUfgBf",
            "7ZZxRm",
            "FMnvBuBU",
            "dVm",
            "a",
            "5iGt03R",
            "GQmaKyO6",
            "a",
            "HJZ",
            "BhTgJuAFaJ",
            "h1UrcL2HM",
        ]
        for exp_str in exp_strs
            @test Serde.ParQuery.unescape(exp_str) == exp_str
        end
    end

    @testset "Case №4: Single escaped character" begin
        @test Serde.ParQuery.unescape("%20") == " "
        @test Serde.ParQuery.unescape("%3C") == "<"
        @test Serde.ParQuery.unescape("%3E") == ">"
        @test Serde.ParQuery.unescape("%26") == "&"
        @test Serde.ParQuery.unescape("%23") == "#"
        @test Serde.ParQuery.unescape("%25") == "%"
    end

    @testset "Case №5: Multiple escaped characters" begin
        @test Serde.ParQuery.unescape("hello%20world") == "hello world"
        @test Serde.ParQuery.unescape("%3C%3E%26%23%25") == "<>&#%"
    end

    @testset "Case №6: Invalid escaped characters" begin
        @test_throws Serde.ParQuery.EscapeError Serde.ParQuery.unescape("%")
        @test_throws Serde.ParQuery.EscapeError Serde.ParQuery.unescape("%0")
        @test_throws Serde.ParQuery.EscapeError Serde.ParQuery.unescape("%z2")
    end

    @testset "Case №7: Decode key" begin
        exp_objs = [
            ("1nrBV3%3d7sF0nuAjKm",    "1nrBV3=7sF0nuAjKm"),
            ("9%3dH3",                 "9=H3"),
            ("YINxlXGxS%3dsbo87p",     "YINxlXGxS=sbo87p"),
            ("cWLG%3ddErpM6P",         "cWLG=dErpM6P"),
            ("zZEL%3dDrJnOC1",         "zZEL=DrJnOC1"),
            ("3Pdp%3dWkh25Lc10",       "3Pdp=Wkh25Lc10"),
            ("zUPkwb9%3dN0g9Vvg22",    "zUPkwb9=N0g9Vvg22"),
            ("rH%3d8XI1jhPR",          "rH=8XI1jhPR"),
            ("U%3d0BOt",               "U=0BOt"),
            ("y%3d0sUGOjdkxz",         "y=0sUGOjdkxz"),
            ("B7Q%3dMJyEt6JSf",        "B7Q=MJyEt6JSf"),
            ("e%3duOTX",               "e=uOTX"),
            ("oRECZu8p%3dQ2UNnja",     "oRECZu8p=Q2UNnja"),
            ("uDfJXxURKQ%3dYV2W5mbyj", "uDfJXxURKQ=YV2W5mbyj"),
            ("6vJ4O1SW%3dnRs",         "6vJ4O1SW=nRs"),
        ]
        for (exp_str, exp_obj) in exp_objs
            @test Serde.ParQuery.decode_key(exp_str) == exp_obj
        end

        @test_throws Serde.ParQuery.QueryParsingError Serde.ParQuery.validate_key(
            "invalid_key;",
        )
    end

    @testset "Case №8: Decode value" begin
        exp_objs = [
            ("1nrBV3%3d7sF0nuAjKm",    "1nrBV3=7sF0nuAjKm"),
            ("9%3dH3",                 "9=H3"),
            ("YINxlXGxS%3dsbo87p",     "YINxlXGxS=sbo87p"),
            ("cWLG%3ddErpM6P",         "cWLG=dErpM6P"),
            ("zZEL%3dDrJnOC1",         "zZEL=DrJnOC1"),
            ("3Pdp%3dWkh25Lc10",       "3Pdp=Wkh25Lc10"),
            ("zUPkwb9%3dN0g9Vvg22",    "zUPkwb9=N0g9Vvg22"),
            ("rH%3d8XI1jhPR",          "rH=8XI1jhPR"),
            ("U%3d0BOt",               "U=0BOt"),
            ("y%3d0sUGOjdkxz",         "y=0sUGOjdkxz"),
            ("B7Q%3dMJyEt6JSf",        "B7Q=MJyEt6JSf"),
            ("e%3duOTX",               "e=uOTX"),
            ("oRECZu8p%3dQ2UNnja",     "oRECZu8p=Q2UNnja"),
            ("uDfJXxURKQ%3dYV2W5mbyj", "uDfJXxURKQ=YV2W5mbyj"),
            ("6vJ4O1SW%3dnRs",         "6vJ4O1SW=nRs"),
        ]
        for (exp_str, exp_obj) in exp_objs
            @test Serde.ParQuery.decode_value(exp_str) == exp_obj
        end
    end

    @testset "Case №9: Parse exp_str" begin
        exp_obj = Dict("name" => ["John Doe"], "age" => ["25"], "city" => ["New York"])
        exp_str = "name=John+Doe&age=25&city=New+York"
        @test Serde.ParQuery.parse(exp_str) == exp_obj

        exp_obj = Dict("a" => ["1", "2", "3"])
        exp_str = "a=1&a=2&a=3"
        @test Serde.ParQuery.parse(exp_str) == exp_obj

        exp_obj = Dict()
        exp_str = ""
        @test Serde.ParQuery.parse(exp_str) == exp_obj

        exp_obj = Dict("name" => ["John Doe"], "age" => [""], "city" => ["New York"])
        exp_str = "name=John+Doe&age=&city=New+York"
        @test Serde.ParQuery.parse(exp_str) == exp_obj

        exp_obj = Dict("@A123" => [""])
        exp_str = "%40%41123"
        @test Serde.ParQuery.parse(exp_str) == exp_obj

        exp_obj = Dict("q" => ["&#20320;&#22909;"])
        exp_str = "q=%26%2320320%3B%26%2322909%3B"
        @test Serde.ParQuery.parse(exp_str) == exp_obj

        exp_obj = Dict("q" => ["&#55296;&#55296;"])
        exp_str = "q=%26%2355296%3B%26%2355296%3B"
        @test Serde.ParQuery.parse(exp_str) == exp_obj

        exp_obj = Dict("q" => ["<asdf>"])
        exp_str = "q=%3Casdf%3E"
        @test Serde.ParQuery.parse(exp_str) == exp_obj

        exp_obj = Dict("q" => ["\"asdf\""])
        exp_str = "q=%22asdf%22"
        @test Serde.ParQuery.parse(exp_str) == exp_obj

        exp_obj = Dict("   foo   " => ["   bar     "])
        exp_str = "   foo   =   bar     "
        @test Serde.ParQuery.parse(exp_str) == exp_obj

        exp_obj = Dict("foo" => ["ａ"])
        exp_str = "foo=%EF%BD%81"
        @test Serde.ParQuery.parse(exp_str) == exp_obj

        exp_obj = Dict("foo" => ["""\xa1\xc1"""])
        exp_str = "foo=%A1%C1"
        @test Serde.ParQuery.parse(exp_str) == exp_obj

        exp_obj = Dict("foo" => ["???"])
        exp_str = "foo=???"
        @test Serde.ParQuery.parse(exp_str) == exp_obj

        exp_obj = Dict("D\xfcrst" => [""])
        exp_str = "D%FCrst"
        @test Serde.ParQuery.parse(exp_str) == exp_obj
    end

    @testset "Case №10: Parse exp_str with different Dict type" begin
        exp_obj = IdDict("name" => "John Doe", "age" => "25", "city" => "New York")
        exp_str = "name=John+Doe&age=25&city=New+York"
        @test Serde.ParQuery.parse_query(exp_str, dict_type = IdDict) == exp_obj
    end

    @testset "Case №11: Parse exp_str with other string types" begin
        exp_obj = Dict("name" => "John Doe", "age" => "25", "city" => "New York")
        exp_str = "name=John+Doe&age=25&city=New+York"
        @test Serde.ParQuery.parse_query(exp_str) == exp_obj
        @test Serde.ParQuery.parse_query(Vector{UInt8}(exp_str)) == exp_obj
        @test Serde.ParQuery.parse_query(SubString(exp_str, 1)) == exp_obj
    end

    @testset "Case №12: Parse exp_str with different delimiter and/or backbone" begin
        exp_obj = Dict("name" => "John Doe", "age" => "25", "city" => "New York")
        exp_str = "name=John+Doe;age=25;city=New+York"
        @test Serde.ParQuery.parse_query(exp_str, delimiter = ";") == exp_obj

        exp_obj = Dict("name" => "John Doe", "age" => "25", "city" => "")
        exp_str = "name=John+Doe&age=25&city"
        @test Serde.ParQuery.parse_query(exp_str, delimiter = "&") == exp_obj

        struct Foo_1
            a::Vector{Int}
        end

        exp_obj = Dict("a" => ["1", "2", "3"])
        exp_str = "a=[1,2,3]"
        @test Serde.ParQuery.parse_query(exp_str; backbone = Foo_1) == exp_obj
    end
end
