# Par/ParQuery

using Random: randstring

@testset verbose = true "ParQuery" begin
    @testset verbose = true "Case №1: Cut" begin
        for i in 1:1000
            key, value = randstring(rand(1:10)), randstring(rand(1:10))
            pair = key * "=" * value
            @test (key, value) == Serde.ParQuery.cut(pair, "=")
        end
    end

    @testset verbose = true "Unescape query" begin
        @testset verbose = true "No need to escape" begin
            @testset "Case №1: Empty string" begin
                @test Serde.ParQuery.unescape("") == ""
            end
            @testset "Case №2: String without escaped characters" begin
                for i in 1:1000
                    query = randstring(['A':'Z'; '0':'9'; 'a':'z'], rand(1:10))
                    @test Serde.ParQuery.unescape(query) == query
                end
            end
        end

        @testset verbose = true "Escaped characters" begin
            @testset "Case №1: Single escaped character" begin
                @test Serde.ParQuery.unescape("%20") == " "
                @test Serde.ParQuery.unescape("%3C") == "<"
                @test Serde.ParQuery.unescape("%3E") == ">"
                @test Serde.ParQuery.unescape("%26") == "&"
                @test Serde.ParQuery.unescape("%23") == "#"
                @test Serde.ParQuery.unescape("%25") == "%"
            end

            @testset "Case №2: Multiple escaped characters" begin
                @test Serde.ParQuery.unescape("hello%20world") == "hello world"
                @test Serde.ParQuery.unescape("%3C%3E%26%23%25") == "<>&#%"
            end

            @testset "Case №3: Invalid escaped characters" begin
                @test_throws Serde.ParQuery.EscapeError Serde.ParQuery.unescape("%")
                @test_throws Serde.ParQuery.EscapeError Serde.ParQuery.unescape("%0")
                @test_throws Serde.ParQuery.EscapeError Serde.ParQuery.unescape("%z2")
            end
        end
    end

    @testset verbose = true "Case №2: Decode key" begin
        for i in 1:1000
            first = randstring(['A':'Z'; '0':'9'; 'a':'z'], rand(1:10))
            second = randstring(['A':'Z'; '0':'9'; 'a':'z'], rand(1:10))
            query = first * "%3d" * second
            @test Serde.ParQuery.decode_key(query) == first * "=" * second
        end
        @test_throws Serde.ParQuery.QueryParsingError Serde.ParQuery.validate_key(
            "invalid_key;",
        )
    end

    @testset verbose = true "Case №3: Decode value" begin
        for i in 1:1000
            first = randstring(['A':'Z'; '0':'9'; 'a':'z'], rand(1:10))
            second = randstring(['A':'Z'; '0':'9'; 'a':'z'], rand(1:10))
            query = first * "%3d" * second
            @test Serde.ParQuery.decode_value(query) == first * "=" * second
        end
    end

    @testset verbose = true "Case №4: Parse query" begin
        query = "name=John+Doe&age=25&city=New+York"
        expected = Dict("name" => ["John Doe"], "age" => ["25"], "city" => ["New York"])
        @test Serde.ParQuery.parse(query) == expected

        query = "a=1&a=2&a=3"
        expected = Dict("a" => ["1", "2", "3"])
        @test Serde.ParQuery.parse(query) == expected

        query = ""
        expected = Dict()
        @test Serde.ParQuery.parse(query) == expected

        query = "name=John+Doe&age=&city=New+York"
        expected = Dict("name" => ["John Doe"], "age" => [""], "city" => ["New York"])
        @test Serde.ParQuery.parse(query) == expected

        query = "name=John+Doe;age=25;city=New+York"
        expected = Dict("name" => ["John Doe"], "age" => ["25"], "city" => ["New York"])
        @test Serde.ParQuery.parse(query, delimiter = ";") == expected

        query = "name=John+Doe&age=25&city"
        expected = Dict("name" => ["John Doe"], "age" => ["25"], "city" => [""])
        @test Serde.ParQuery.parse(query, delimiter = "&") == expected
    end
end
