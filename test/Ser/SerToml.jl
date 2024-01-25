# Ser/SerToml

@testset verbose = true "SerToml" begin
    @testset "Case №1: Dict to Toml" begin
        h = Dict(
            "bar" => "test",
            "foo" => Dict(
                "baz" => "hi",
                "conf" => Dict(
                    "boo" => "aaa",
                    "monf" => Dict("abbr" => "ppp", "mint" => "coconut"),
                    "tonf" => Dict("aqua" => "cyan"),
                ),
            ),
        )
        expected = """
        bar = "test"

        [foo]
        baz = "hi"

          [foo.conf]
          boo = "aaa"

            [foo.conf.monf]
            mint = "coconut"
            abbr = "ppp"

            [foo.conf.tonf]
            aqua = "cyan"
        """
        @test Serde.to_toml(h) == expected

        h = Dict(
            "bar" => "test",
            "foo" => Dict(
                "baz" => :hi,
                :conf => Dict(
                    "boo" => "aaa",
                    "monf" => Dict("abbr" => "ppp", "mint" => "coconut"),
                    "tonf" => Dict("aqua" => "cyan"),
                ),
            ),
        )
        @test Serde.to_toml(h) == expected

        h = Dict(
            "bar" => "test",
            123_456 => Dict(
                "baz" => :hi,
                :conf => Dict(
                    "boo" => "aaa",
                    "monf" => Dict("abbr" => "ppp", "mint" => true),
                    "tonf" => Dict("aqua" => "cyan"),
                ),
            ),
        )
        expected = """
        bar = "test"

        [123456]
        baz = "hi"

          [123456.conf]
          boo = "aaa"

            [123456.conf.monf]
            mint = true
            abbr = "ppp"

            [123456.conf.tonf]
            aqua = "cyan"
        """
        @test Serde.to_toml(h) == expected
    end

    @testset "Case №2: Struct to Toml" begin
        struct Bar1
            v1::Int64
            v2::String
        end

        struct Bar2
            v1::Int64
            v2::String
        end

        struct Fooo
            val::Int64
            bar1::Bar1
            bar2::Vector{Bar2}
        end

        Serde.SerToml.ser_name(::Type{Fooo}, ::Val{:val}) = :test
        Serde.SerToml.ser_value(::Type{Fooo}, ::Val{:bar1}, x::Bar1) = 1

        expected = """
        test = 100
        bar1 = 1

        [[bar2]]
        v1 = 100
        v2 = "ds"

        [[bar2]]
        v1 = 100
        v2 = "ds"
        """
        @test Serde.to_toml(
            Fooo(100, Bar1(100, "ds"), [Bar2(100, "ds"), Bar2(100, "ds")]),
        ) == expected
    end

    @testset "Case №3: Vectors with mixed types" begin
        struct BarToml3
            a::Int64
            d::String
        end

        expected = """

        [[key]]
        a = 100
        d = "ds"

        [[key]]
        name = "imya"
        age = 1
        """

        @test Serde.to_toml(Dict("key" => [1, 2.2, "d"])) == "key = [1,2.2,\"d\"]\n"
        @test Serde.to_toml(
            Dict("key" => [BarToml3(100, "ds"), Dict("name" => "imya", "age" => 1)]),
        ) == expected

        @test_throws "TomlSerializationError: mix simple and complex types" begin
            Serde.to_toml(Dict("key" => ["1", "2", BarToml3(100, "ds")]))
        end
    end

    @testset "Case №4: Backward compatibility" begin
        toml = """
        variable_dump_dir = "%{DUMP_PATH}%/some_app"
        generator_publisher_name = "%{CURRENT_FILE}%"

        [some_config]
        some_server_host = "0.0.0.0"
        some_server_port = 8080

        some_server_refresh_token_name = "App"
        some_server_session_timeout = 86400

          [[some_config.some_accounts]]
          username = "test1"
          password = "sha256_79c12fd077a3996fd101b53b211b320acec4003fb"
            [some_config.some_accounts.role]

          [[some_config.some_accounts]]
          username = "test2"
          password = "sha256_79c12fd077a3996fd101b53b211b320acec4003fb"
            [some_config.some_accounts.role]
        """

        parsed_toml = Serde.parse_toml(toml)
        reparsed_toml = Serde.parse_toml(Serde.to_toml(parsed_toml))
        @test parsed_toml == reparsed_toml
    end

    @testset "Case №5: Time types" begin
        struct TomlSerFoo5
            first_date::Date
            time::Time
            second_date::DateTime
            nanodate::NanoDate
        end

        struct TomlSerBar
            toml_ser_foo_5::TomlSerFoo5
        end

        function Serde.deser(::Type{TomlSerFoo5}, ::Type{Date}, v::String)
            return Dates.Date(v, "U d, yyyy")
        end

        function Serde.deser(::Type{TomlSerFoo5}, ::Type{NanoDate}, v::String)
            return NanoDate(v)
        end

        toml = """
        [toml_ser_foo_5]
        first_date = "July 13, 2024"
        time = 14:41:59.316
        second_date = 2024-01-23T14:42:14.316Z
        nanodate = "2024-01-23T14:42:14.316366122"
        """

        @test to_toml(deser_toml(TomlSerBar, toml)) == """
        \n[toml_ser_foo_5]
        first_date = 2024-07-13
        time = 14:41:59.316
        second_date = 2024-01-23T14:42:14.316Z
        nanodate = "2024-01-23T14:42:14.316366122"
        """
    end
end
