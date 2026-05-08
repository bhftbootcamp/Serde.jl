# test_context.jl — Context support tests

module TestContext

using Serde
using Test, Dates

# ─── Test types ───

struct ApiCtx end
struct LogCtx end

struct Order
    id::Int
    name::String
    created_at::String
    secret_key::String
end

# ser_value: transform value for API
Serde.ser_value(::ApiCtx, ::Type{Order}, ::Val{:created_at}, v) = uppercase(v)

# ser_skip: always hide secret_key in logs
Serde.ser_skip(::LogCtx, ::Type{Order}, ::Val{:secret_key}) = true

# ser_name: rename field for API
Serde.ser_name(::ApiCtx, ::Type{Order}, ::Val{:created_at}) = :createdAt

# deser_name: accept camelCase in API context
Serde.deser_name(::ApiCtx, ::Type{Order}, ::Val{:created_at}) = :createdAt

# ─── has_default / deser_default ───

struct Config
    host::String
    port::Int
end

Serde.has_default(::ApiCtx, ::Type{Config}, ::Val{:port}) = true
Serde.deser_default(::ApiCtx, ::Type{Config}, ::Val{:port}) = 443
Serde.has_default(::LogCtx, ::Type{Config}, ::Val{:port}) = true
Serde.deser_default(::LogCtx, ::Type{Config}, ::Val{:port}) = 9200

# ─── deser_validate ───

struct UserInput
    age::Int
    name::String
end

function Serde.deser_validate(::ApiCtx, ::Type{UserInput}, ::Val{:age}, v)
    v < 0 && throw(Serde.ValidationError(UserInput, :age, v, "age must be non-negative"))
    nothing
end

# ─── Nested structs ───

struct Inner
    value::Int
    label::String
end

struct Outer
    inner::Inner
    tag::String
end

Serde.ser_name(::ApiCtx, ::Type{Inner}, ::Val{:label}) = :lbl
Serde.ser_value(::ApiCtx, ::Type{Outer}, ::Val{:tag}, v) = uppercase(v)

# ─── ser_type ───

struct RoundCtx
    digits::Int
end

struct Measurement
    value::Float64
    unit::String
end

Serde.ser_type(strategy::RoundCtx, ::Type{Measurement}, v::Float64) = round(v; digits = strategy.digits)

# ─── isempty_value ───

struct TrimCtx end

struct Comment
    text::Union{Nothing,String}
    author::String
end

Serde.isempty_value(::TrimCtx, ::Type{Comment}, ::Val{:text}, v::String) = isempty(strip(v))

# ─── deser_transform ───

struct LowerCtx end

struct Tag
    label::String
    code::String
end

Serde.deser_transform(::LowerCtx, ::Type{Tag}, ::Type{String}, v) = lowercase(v)

# ─── ser_skip without value (always skip) ───

struct MinimalCtx end

struct Verbose
    essential::String
    debug_info::String
    trace_id::String
end

Serde.ser_skip(::MinimalCtx, ::Type{Verbose}, ::Val{:debug_info}) = true
Serde.ser_skip(::MinimalCtx, ::Type{Verbose}, ::Val{:trace_id}) = true

# ─── Tests ───

@testset "Context Support" begin

    # ── Serialization traits ──

    @testset "ser_name — rename fields" begin
        order = Order(1, "test", "jan-first", "sk_secret")

        json_api = to_json(ApiCtx(), order)
        @test occursin("\"createdAt\"", json_api)
        @test !occursin("\"created_at\"", json_api)

        json_default = to_json(order)
        @test occursin("\"created_at\"", json_default)
        @test !occursin("\"createdAt\"", json_default)
    end

    @testset "ser_value — transform values" begin
        order = Order(1, "test", "jan-first", "sk_secret")

        json_api = to_json(ApiCtx(), order)
        @test occursin("JAN-FIRST", json_api)

        json_default = to_json(order)
        @test occursin("jan-first", json_default)
        @test !occursin("JAN-FIRST", json_default)
    end

    @testset "ser_skip with value — conditional skip" begin
        order = Order(1, "test", "jan-first", "sk_secret")

        json_log = to_json(LogCtx(), order)
        @test !occursin("secret_key", json_log)
        @test occursin("\"created_at\"", json_log)

        json_api = to_json(ApiCtx(), order)
        @test occursin("secret_key", json_api)
    end

    @testset "ser_skip without value — always skip" begin
        v = Verbose("data", "dbg_123", "tr_456")

        json_min = to_json(MinimalCtx(), v)
        @test occursin("\"essential\"", json_min)
        @test !occursin("debug_info", json_min)
        @test !occursin("trace_id", json_min)

        json_full = to_json(v)
        @test occursin("debug_info", json_full)
        @test occursin("trace_id", json_full)
    end

    @testset "ser_type — type-level transform" begin
        m = Measurement(3.14159265, "m/s")

        json_r2 = to_json(RoundCtx(2), m)
        @test occursin("3.14", json_r2)
        @test !occursin("3.14159", json_r2)

        json_r4 = to_json(RoundCtx(4), m)
        @test occursin("3.1416", json_r4)

        json_default = to_json(m)
        @test occursin("3.14159265", json_default)
    end

    @testset "ser_type — context with data" begin
        m = Measurement(2.71828, "kg")
        @test to_json(RoundCtx(1), m) != to_json(RoundCtx(3), m)
    end

    # ── Deserialization traits ──

    @testset "deser_name — accept alternative names" begin
        json_api = """{"id":1,"name":"test","createdAt":"jan-first","secret_key":"sk"}"""
        order = from_json(ApiCtx(), Order, json_api)
        @test order.id == 1
        @test order.created_at == "jan-first"

        json_default = """{"id":1,"name":"test","created_at":"jan-first","secret_key":"sk"}"""
        order2 = from_json(Order, json_default)
        @test order2.created_at == "jan-first"
    end

    @testset "has_default / deser_default" begin
        json = """{"host":"localhost"}"""

        config_api = from_json(ApiCtx(), Config, json)
        @test config_api.port == 443

        config_log = from_json(LogCtx(), Config, json)
        @test config_log.port == 9200
    end

    @testset "deser_validate" begin
        json_ok = """{"age":25,"name":"Alice"}"""
        user = from_json(ApiCtx(), UserInput, json_ok)
        @test user.age == 25

        json_bad = """{"age":-1,"name":"Bob"}"""
        @test_throws Serde.ValidationError from_json(ApiCtx(), UserInput, json_bad)

        # Without context: no validation
        user_no_ctx = from_json(UserInput, json_bad)
        @test user_no_ctx.age == -1
    end

    @testset "isempty_value" begin
        json = """{"text":"   ","author":"Bob"}"""
        c = from_json(TrimCtx(), Comment, json)
        @test c.text === nothing

        c2 = from_json(Comment, json)
        @test c2.text == "   "
    end

    @testset "deser_transform" begin
        json = """{"label":"RUST","code":"RS"}"""
        t = from_json(LowerCtx(), Tag, json)
        @test t.label == "rust"
        @test t.code == "rs"

        t2 = from_json(Tag, json)
        @test t2.label == "RUST"
        @test t2.code == "RS"
    end

    # ── Structural tests ──

    @testset "Nested structs — strategy propagates" begin
        outer = Outer(Inner(42, "hello"), "world")

        json_api = to_json(ApiCtx(), outer)
        @test occursin("\"lbl\"", json_api)
        @test occursin("WORLD", json_api)

        json_default = to_json(outer)
        @test occursin("\"label\"", json_default)
        @test occursin("\"world\"", json_default)
    end

    @testset "Backward compatibility — no context" begin
        order = Order(1, "test", "jan-first", "sk_secret123")
        json = to_json(order)
        order2 = from_json(Order, json)
        @test order.id == order2.id
        @test order.name == order2.name
        @test order.created_at == order2.created_at
        @test order.secret_key == order2.secret_key
    end

    @testset "Two contexts for one struct" begin
        order = Order(1, "test", "jan-first", "sk_secret")

        json_api = to_json(ApiCtx(), order)
        json_log = to_json(LogCtx(), order)

        @test json_api != json_log
        @test occursin("createdAt", json_api)
        @test !occursin("createdAt", json_log)
        @test !occursin("secret_key", json_log)
        @test occursin("secret_key", json_api)
    end

    # ── JSON specific ──

    @testset "try_from_json with context" begin
        json = """{"id":1,"name":"test","createdAt":"jan-first","secret_key":"sk"}"""
        result = try_from_json(ApiCtx(), Order, json)
        @test result isa Order
        @test result.id == 1

        bad_json = "not json"
        result_err = try_from_json(ApiCtx(), Order, bad_json)
        @test result_err isa Exception
    end

    @testset "Pretty JSON with context" begin
        order = Order(1, "test", "jan-first", "sk_secret")
        pretty = to_pretty_json(ApiCtx(), order)
        @test occursin("\"createdAt\"", pretty)
        @test occursin("\n", pretty)
    end

    @testset "JSON roundtrip with context" begin
        order = Order(1, "test", "jan-first", "sk_secret")
        json_api = to_json(ApiCtx(), order)
        order2 = from_json(ApiCtx(), Order, json_api)
        @test order2.id == order.id
        @test order2.name == order.name
        @test order2.created_at == uppercase(order.created_at)
        @test order2.secret_key == order.secret_key
    end

    # ── TOML ──

    @testset "TOML ser with context" begin
        order = Order(1, "test", "jan-first", "sk_secret")

        toml_api = to_toml(ApiCtx(), order)
        @test occursin("createdAt", toml_api)
        @test occursin("JAN-FIRST", toml_api)

        toml_log = to_toml(LogCtx(), order)
        @test !occursin("secret_key", toml_log)
    end

    @testset "TOML deser with context" begin
        toml = """host = "db.local"\n"""
        config = from_toml(ApiCtx(), Config, toml)
        @test config.host == "db.local"
        @test config.port == 443

        config2 = from_toml(LogCtx(), Config, toml)
        @test config2.port == 9200
    end

    # ── YAML ──

    @testset "YAML ser with context" begin
        order = Order(1, "test", "jan-first", "sk_secret")

        yaml_api = to_yaml(ApiCtx(), order)
        @test occursin("createdAt", yaml_api)
        @test occursin("JAN-FIRST", yaml_api)

        yaml_log = to_yaml(LogCtx(), order)
        @test !occursin("secret_key", yaml_log)
    end

    @testset "YAML deser with context" begin
        yaml = "host: db.local\n"
        config = from_yaml(ApiCtx(), Config, yaml)
        @test config.host == "db.local"
        @test config.port == 443
    end

    # ── MsgPack ──

    @testset "MsgPack ser with context" begin
        order = Order(1, "test", "jan-first", "sk_secret")

        bytes_api = to_msgpack(ApiCtx(), order)
        bytes_default = to_msgpack(order)
        @test bytes_api != bytes_default
    end

    @testset "MsgPack deser with context" begin
        config_bytes = to_msgpack(Dict("host" => "localhost"))
        config = from_msgpack(ApiCtx(), Config, config_bytes)
        @test config.host == "localhost"
        @test config.port == 443
    end

    @testset "MsgPack try_from with context" begin
        config_bytes = to_msgpack(Dict("host" => "localhost"))
        result = try_from_msgpack(ApiCtx(), Config, config_bytes)
        @test result isa Config
        @test result.port == 443

        bad_bytes = UInt8[0xff]
        result_err = try_from_msgpack(ApiCtx(), Config, bad_bytes)
        @test result_err isa Exception
    end

    # ── BSON ──

    @testset "BSON ser with context" begin
        order = Order(1, "test", "jan-first", "sk_secret")

        bson_api = to_bson(ApiCtx(), order)
        bson_default = to_bson(order)
        @test bson_api != bson_default
    end

    @testset "BSON deser with context" begin
        bson_bytes = to_bson(Dict("host" => "localhost"))
        config = from_bson(ApiCtx(), Config, bson_bytes)
        @test config.host == "localhost"
        @test config.port == 443
    end

    @testset "BSON try_from with context" begin
        bson_bytes = to_bson(Dict("host" => "localhost"))
        result = try_from_bson(ApiCtx(), Config, bson_bytes)
        @test result isa Config
        @test result.port == 443
    end

    # ── XML ──

    @testset "XML ser with context" begin
        order = Order(1, "test", "jan-first", "sk_secret")

        xml_api = to_xml(ApiCtx(), order; key = "order")
        @test occursin("createdAt=", xml_api)
        @test occursin("JAN-FIRST", xml_api)

        xml_log = to_xml(LogCtx(), order; key = "order")
        @test !occursin("secret_key", xml_log)
    end

    @testset "XML ser nested — strategy propagates" begin
        outer = Outer(Inner(42, "hello"), "world")
        xml_api = to_xml(ApiCtx(), outer; key = "root")
        @test occursin("lbl=", xml_api)
        @test occursin("WORLD", xml_api)
    end

    @testset "XML deser with context" begin
        xml = """<order id="1" name="test" createdAt="jan-first" secret_key="sk"/>"""
        order = from_xml(ApiCtx(), Order, xml)
        @test order.id == 1
        @test order.name == "test"
    end

    # ── Query ──

    @testset "Query ser with context" begin
        order = Order(1, "test", "jan-first", "sk_secret")

        q_api = to_query(ApiCtx(), order)
        @test occursin("createdAt=", q_api)
        @test occursin("JAN-FIRST", q_api)

        q_log = to_query(LogCtx(), order)
        @test !occursin("secret_key", q_log)
    end

    @testset "Query deser with context" begin
        q = "host=db.local"
        config = from_query(ApiCtx(), Config, q)
        @test config.host == "db.local"
        @test config.port == 443
    end

    @testset "Query try_from with context" begin
        q = "host=db.local"
        result = try_from_query(ApiCtx(), Config, q)
        @test result isa Config
        @test result.port == 443
    end

    # ── CSV ──

    @testset "CSV ser with context" begin
        order = Order(1, "test", "jan-first", "sk_secret")

        csv_api = to_csv(ApiCtx(), [order])
        lines = split(csv_api, '\n')
        @test occursin("createdAt", lines[1])
        @test occursin("JAN-FIRST", lines[2])

        csv_log = to_csv(LogCtx(), [order])
        @test !occursin("secret_key", csv_log)
    end

    @testset "CSV ser — always-skip with context" begin
        v = Verbose("data", "dbg", "tr")
        csv = to_csv(MinimalCtx(), [v])
        @test occursin("essential", csv)
        @test !occursin("debug_info", csv)
        @test !occursin("trace_id", csv)
    end

    @testset "CSV deser with context" begin
        csv = "host\ndb.local\n"
        configs = from_csv(ApiCtx(), Config, csv)
        @test length(configs) == 1
        @test configs[1].host == "db.local"
        @test configs[1].port == 443
    end

    # ── ser_pairs ──

    @testset "ser_pairs with context" begin
        order = Order(1, "test", "jan-first", "sk_secret")

        pairs_api = Serde.ser_pairs(ApiCtx(), order)
        names_api = [p[1] for p in pairs_api]
        @test :createdAt in names_api
        @test :secret_key in names_api

        pairs_log = Serde.ser_pairs(LogCtx(), order)
        names_log = [p[1] for p in pairs_log]
        @test :secret_key ∉ names_log
        @test :created_at in names_log
    end
end

end # module
