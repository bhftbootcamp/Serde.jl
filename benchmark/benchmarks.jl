push!(LOAD_PATH, @__DIR__)

using BenchmarkTools
using Serde

const SUITE = BenchmarkGroup()

# ─────────────────────────────────────────────────────────────────────────────
#  Shared struct definitions
# ─────────────────────────────────────────────────────────────────────────────

struct Tick
    symbol::String
    price::Float64
    volume::Int
    ts::Int
end

struct Order
    id::String
    symbol::String
    side::String
    price::Float64
    amount::Float64
    filled::Float64
    status::String
    timestamp::Int
end

struct Config
    host::String
    port::Int
    debug::Bool
    timeout::Float64
    retries::Int
    name::String
    version::String
    workers::Int
    buffer_size::Int
    log_level::String
    compress::Bool
    keep_alive::Bool
end

struct Position
    x::Float64
    y::Float64
    z::Float64
end

struct Entity
    id::Int
    name::String
    pos::Position
    health::Float64
    active::Bool
end

struct L3
    value::Int
end

struct L2
    items::Vector{L3}
    label::String
end

struct L1
    nested::L2
    count::Int
    tags::Vector{String}
end

struct UserProfile
    id::Int
    name::String
    email::Union{Nothing,String}
    age::Union{Nothing,Int}
    verified::Bool
end

# ─────────────────────────────────────────────────────────────────────────────
#  Test data
# ─────────────────────────────────────────────────────────────────────────────

const TICK     = Tick("BTCUSDT", 67234.5, 1_500_000, 1718451234567)
const ORDER    = Order("ord-123456", "ETHUSDT", "buy", 3456.78, 10.0, 5.5, "partial", 1718451234567)
const CFG      = Config("localhost", 8080, true, 30.0, 3, "myapp", "1.2.3", 4, 65536, "info", true, false)
const ENTITY   = Entity(1, "player1", Position(10.5, 20.3, -5.0), 100.0, true)
const PROFILE  = UserProfile(42, "Alice", "alice@example.com", 30, true)
const PROF_NIL = UserProfile(43, "Bob", nothing, nothing, false)
const DEEP     = L1(L2([L3(i) for i in 1:10], "batch"), 999, ["alpha", "beta", "gamma"])

const TICKS_100  = [Tick("SYM$i", 100.0 + i * 0.1, i * 1000, 1718451234567 + i) for i in 1:100]
const TICKS_1000 = [Tick("SYM$i", 100.0 + i * 0.1, i * 1000, 1718451234567 + i) for i in 1:1000]
const ORDERS_100 = [Order("o$i", "BTCUSDT", isodd(i) ? "buy" : "sell", 67000.0 + i, 1.0 + i * 0.01, 0.5 * i, "open", 1718451234567 + i) for i in 1:100]

const BIG_DICT   = Dict("key_$i" => i % 2 == 0 ? string(i) : i for i in 1:200)
const STR_HEAVY  = Dict("field_$i" => "x"^(10 + i % 50) for i in 1:50)

# ─────────────────────────────────────────────────────────────────────────────
#  Pre-serialized payloads
# ─────────────────────────────────────────────────────────────────────────────

const JSON_TICK     = to_json(TICK)
const JSON_ORDER    = to_json(ORDER)
const JSON_CFG      = to_json(CFG)
const JSON_ENTITY   = to_json(ENTITY)
const JSON_DEEP     = to_json(DEEP)
const JSON_100T     = to_json(TICKS_100)
const JSON_1000T    = to_json(TICKS_1000)
const JSON_BIGDICT  = to_json(BIG_DICT)
const JSON_PROFILE  = to_json(PROFILE)
const JSON_PROFNIL  = to_json(PROF_NIL)

const TOML_TICK = to_toml(TICK)
const TOML_CFG  = to_toml(CFG)

const QUERY_TICK = to_query(TICK)
const QUERY_CFG  = to_query(CFG)

const CSV_100T = to_csv(TICKS_100)
const CSV_100O = to_csv(ORDERS_100)

const MP_TICK   = to_msgpack(TICK)
const MP_ORDER  = to_msgpack(ORDER)
const MP_CFG    = to_msgpack(CFG)
const MP_DEEP   = to_msgpack(DEEP)
const MP_100T   = to_msgpack(TICKS_100)
const MP_1000T  = to_msgpack(TICKS_1000)

const BSON_TICK  = to_bson(TICK)
const BSON_ORDER = to_bson(ORDER)
const BSON_CFG   = to_bson(CFG)
const BSON_DEEP  = to_bson(DEEP)

# ═══════════════════════════════════════════════════════════════════════════════
#  1. JSON
# ═══════════════════════════════════════════════════════════════════════════════

SUITE["json"] = BenchmarkGroup(["json"])

# ─────────────────────────────────────────────────────────────────────────────
#  1.1 Serialization
# ─────────────────────────────────────────────────────────────────────────────

SUITE["json"]["ser"] = BenchmarkGroup(["serialization"])

SUITE["json"]["ser"]["tick"]        = @benchmarkable to_json($TICK)
SUITE["json"]["ser"]["order"]       = @benchmarkable to_json($ORDER)
SUITE["json"]["ser"]["config"]      = @benchmarkable to_json($CFG)
SUITE["json"]["ser"]["entity"]      = @benchmarkable to_json($ENTITY)
SUITE["json"]["ser"]["deep"]        = @benchmarkable to_json($DEEP)
SUITE["json"]["ser"]["100_ticks"]   = @benchmarkable to_json($TICKS_100)
SUITE["json"]["ser"]["1000_ticks"]  = @benchmarkable to_json($TICKS_1000)
SUITE["json"]["ser"]["100_orders"]  = @benchmarkable to_json($ORDERS_100)
SUITE["json"]["ser"]["big_dict"]    = @benchmarkable to_json($BIG_DICT)
SUITE["json"]["ser"]["str_heavy"]   = @benchmarkable to_json($STR_HEAVY)
SUITE["json"]["ser"]["null_profile"] = @benchmarkable to_json($PROF_NIL)

# ─────────────────────────────────────────────────────────────────────────────
#  1.2 Deserialization
# ─────────────────────────────────────────────────────────────────────────────

SUITE["json"]["deser"] = BenchmarkGroup(["deserialization"])

SUITE["json"]["deser"]["tick"]       = @benchmarkable from_json(Tick, $JSON_TICK)
SUITE["json"]["deser"]["order"]      = @benchmarkable from_json(Order, $JSON_ORDER)
SUITE["json"]["deser"]["config"]     = @benchmarkable from_json(Config, $JSON_CFG)
SUITE["json"]["deser"]["entity"]     = @benchmarkable from_json(Entity, $JSON_ENTITY)
SUITE["json"]["deser"]["deep"]       = @benchmarkable from_json(L1, $JSON_DEEP)
SUITE["json"]["deser"]["100_ticks"]  = @benchmarkable from_json(Vector{Tick}, $JSON_100T)
SUITE["json"]["deser"]["1000_ticks"] = @benchmarkable from_json(Vector{Tick}, $JSON_1000T)
SUITE["json"]["deser"]["null_profile"] = @benchmarkable from_json(UserProfile, $JSON_PROFNIL)

# ─────────────────────────────────────────────────────────────────────────────
#  1.3 Parse (JSON → Dict)
# ─────────────────────────────────────────────────────────────────────────────

SUITE["json"]["parse"] = BenchmarkGroup(["parsing"])

SUITE["json"]["parse"]["tick"]       = @benchmarkable parse_json($JSON_TICK)
SUITE["json"]["parse"]["1000_ticks"] = @benchmarkable parse_json($JSON_1000T)
SUITE["json"]["parse"]["big_dict"]   = @benchmarkable parse_json($JSON_BIGDICT)

# ─────────────────────────────────────────────────────────────────────────────
#  1.4 Round-trip
# ─────────────────────────────────────────────────────────────────────────────

SUITE["json"]["roundtrip"] = BenchmarkGroup(["roundtrip"])

SUITE["json"]["roundtrip"]["tick"]      = @benchmarkable from_json(Tick, to_json($TICK))
SUITE["json"]["roundtrip"]["100_ticks"] = @benchmarkable from_json(Vector{Tick}, to_json($TICKS_100))

# ═══════════════════════════════════════════════════════════════════════════════
#  2. MsgPack
# ═══════════════════════════════════════════════════════════════════════════════

SUITE["msgpack"] = BenchmarkGroup(["msgpack"])

# ─────────────────────────────────────────────────────────────────────────────
#  2.1 Serialization
# ─────────────────────────────────────────────────────────────────────────────

SUITE["msgpack"]["ser"] = BenchmarkGroup(["serialization"])

SUITE["msgpack"]["ser"]["tick"]       = @benchmarkable to_msgpack($TICK)
SUITE["msgpack"]["ser"]["order"]      = @benchmarkable to_msgpack($ORDER)
SUITE["msgpack"]["ser"]["config"]     = @benchmarkable to_msgpack($CFG)
SUITE["msgpack"]["ser"]["entity"]     = @benchmarkable to_msgpack($ENTITY)
SUITE["msgpack"]["ser"]["deep"]       = @benchmarkable to_msgpack($DEEP)
SUITE["msgpack"]["ser"]["100_ticks"]  = @benchmarkable to_msgpack($TICKS_100)
SUITE["msgpack"]["ser"]["1000_ticks"] = @benchmarkable to_msgpack($TICKS_1000)
SUITE["msgpack"]["ser"]["big_dict"]   = @benchmarkable to_msgpack($BIG_DICT)

# ─────────────────────────────────────────────────────────────────────────────
#  2.2 Deserialization
# ─────────────────────────────────────────────────────────────────────────────

SUITE["msgpack"]["deser"] = BenchmarkGroup(["deserialization"])

SUITE["msgpack"]["deser"]["tick"]       = @benchmarkable from_msgpack(Tick, $MP_TICK)
SUITE["msgpack"]["deser"]["order"]      = @benchmarkable from_msgpack(Order, $MP_ORDER)
SUITE["msgpack"]["deser"]["config"]     = @benchmarkable from_msgpack(Config, $MP_CFG)
SUITE["msgpack"]["deser"]["deep"]       = @benchmarkable from_msgpack(L1, $MP_DEEP)
SUITE["msgpack"]["deser"]["100_ticks"]  = @benchmarkable from_msgpack(Vector{Tick}, $MP_100T)
SUITE["msgpack"]["deser"]["1000_ticks"] = @benchmarkable from_msgpack(Vector{Tick}, $MP_1000T)

# ─────────────────────────────────────────────────────────────────────────────
#  2.3 Parse
# ─────────────────────────────────────────────────────────────────────────────

SUITE["msgpack"]["parse"] = BenchmarkGroup(["parsing"])

SUITE["msgpack"]["parse"]["tick"]       = @benchmarkable parse_msgpack($MP_TICK)
SUITE["msgpack"]["parse"]["1000_ticks"] = @benchmarkable parse_msgpack($MP_1000T)

# ─────────────────────────────────────────────────────────────────────────────
#  2.4 Round-trip
# ─────────────────────────────────────────────────────────────────────────────

SUITE["msgpack"]["roundtrip"] = BenchmarkGroup(["roundtrip"])

SUITE["msgpack"]["roundtrip"]["tick"]      = @benchmarkable from_msgpack(Tick, to_msgpack($TICK))
SUITE["msgpack"]["roundtrip"]["100_ticks"] = @benchmarkable from_msgpack(Vector{Tick}, to_msgpack($TICKS_100))

# ═══════════════════════════════════════════════════════════════════════════════
#  3. BSON
# ═══════════════════════════════════════════════════════════════════════════════

SUITE["bson"] = BenchmarkGroup(["bson"])

# ─────────────────────────────────────────────────────────────────────────────
#  3.1 Serialization
# ─────────────────────────────────────────────────────────────────────────────

SUITE["bson"]["ser"] = BenchmarkGroup(["serialization"])

SUITE["bson"]["ser"]["tick"]     = @benchmarkable to_bson($TICK)
SUITE["bson"]["ser"]["order"]    = @benchmarkable to_bson($ORDER)
SUITE["bson"]["ser"]["config"]   = @benchmarkable to_bson($CFG)
SUITE["bson"]["ser"]["entity"]   = @benchmarkable to_bson($ENTITY)
SUITE["bson"]["ser"]["deep"]     = @benchmarkable to_bson($DEEP)
SUITE["bson"]["ser"]["big_dict"] = @benchmarkable to_bson($BIG_DICT)

# ─────────────────────────────────────────────────────────────────────────────
#  3.2 Deserialization
# ─────────────────────────────────────────────────────────────────────────────

SUITE["bson"]["deser"] = BenchmarkGroup(["deserialization"])

SUITE["bson"]["deser"]["tick"]   = @benchmarkable from_bson(Tick, $BSON_TICK)
SUITE["bson"]["deser"]["order"]  = @benchmarkable from_bson(Order, $BSON_ORDER)
SUITE["bson"]["deser"]["config"] = @benchmarkable from_bson(Config, $BSON_CFG)
SUITE["bson"]["deser"]["deep"]   = @benchmarkable from_bson(L1, $BSON_DEEP)

# ─────────────────────────────────────────────────────────────────────────────
#  3.3 Parse
# ─────────────────────────────────────────────────────────────────────────────

SUITE["bson"]["parse"] = BenchmarkGroup(["parsing"])

SUITE["bson"]["parse"]["tick"] = @benchmarkable parse_bson($BSON_TICK)

# ─────────────────────────────────────────────────────────────────────────────
#  3.4 Round-trip
# ─────────────────────────────────────────────────────────────────────────────

SUITE["bson"]["roundtrip"] = BenchmarkGroup(["roundtrip"])

SUITE["bson"]["roundtrip"]["tick"] = @benchmarkable from_bson(Tick, to_bson($TICK))

# ═══════════════════════════════════════════════════════════════════════════════
#  4. TOML
# ═══════════════════════════════════════════════════════════════════════════════

SUITE["toml"] = BenchmarkGroup(["toml"])

# ─────────────────────────────────────────────────────────────────────────────
#  4.1 Serialization
# ─────────────────────────────────────────────────────────────────────────────

SUITE["toml"]["ser"] = BenchmarkGroup(["serialization"])

SUITE["toml"]["ser"]["tick"]   = @benchmarkable to_toml($TICK)
SUITE["toml"]["ser"]["config"] = @benchmarkable to_toml($CFG)

# ─────────────────────────────────────────────────────────────────────────────
#  4.2 Deserialization
# ─────────────────────────────────────────────────────────────────────────────

SUITE["toml"]["deser"] = BenchmarkGroup(["deserialization"])

SUITE["toml"]["deser"]["tick"]   = @benchmarkable from_toml(Tick, $TOML_TICK)
SUITE["toml"]["deser"]["config"] = @benchmarkable from_toml(Config, $TOML_CFG)

# ─────────────────────────────────────────────────────────────────────────────
#  4.3 Parse
# ─────────────────────────────────────────────────────────────────────────────

SUITE["toml"]["parse"] = BenchmarkGroup(["parsing"])

SUITE["toml"]["parse"]["tick"]   = @benchmarkable parse_toml($TOML_TICK)
SUITE["toml"]["parse"]["config"] = @benchmarkable parse_toml($TOML_CFG)

# ─────────────────────────────────────────────────────────────────────────────
#  4.4 Round-trip
# ─────────────────────────────────────────────────────────────────────────────

SUITE["toml"]["roundtrip"] = BenchmarkGroup(["roundtrip"])

SUITE["toml"]["roundtrip"]["tick"] = @benchmarkable from_toml(Tick, to_toml($TICK))

# ═══════════════════════════════════════════════════════════════════════════════
#  5. Query
# ═══════════════════════════════════════════════════════════════════════════════

SUITE["query"] = BenchmarkGroup(["query"])

# ─────────────────────────────────────────────────────────────────────────────
#  5.1 Serialization
# ─────────────────────────────────────────────────────────────────────────────

SUITE["query"]["ser"] = BenchmarkGroup(["serialization"])

SUITE["query"]["ser"]["tick"]   = @benchmarkable to_query($TICK)
SUITE["query"]["ser"]["config"] = @benchmarkable to_query($CFG)

# ─────────────────────────────────────────────────────────────────────────────
#  5.2 Deserialization
# ─────────────────────────────────────────────────────────────────────────────

SUITE["query"]["deser"] = BenchmarkGroup(["deserialization"])

SUITE["query"]["deser"]["tick"]   = @benchmarkable from_query(Tick, $QUERY_TICK)
SUITE["query"]["deser"]["config"] = @benchmarkable from_query(Config, $QUERY_CFG)

# ─────────────────────────────────────────────────────────────────────────────
#  5.3 Round-trip
# ─────────────────────────────────────────────────────────────────────────────

SUITE["query"]["roundtrip"] = BenchmarkGroup(["roundtrip"])

SUITE["query"]["roundtrip"]["tick"] = @benchmarkable from_query(Tick, to_query($TICK))

# ═══════════════════════════════════════════════════════════════════════════════
#  6. CSV
# ═══════════════════════════════════════════════════════════════════════════════

SUITE["csv"] = BenchmarkGroup(["csv"])

# ─────────────────────────────────────────────────────────────────────────────
#  6.1 Serialization
# ─────────────────────────────────────────────────────────────────────────────

SUITE["csv"]["ser"] = BenchmarkGroup(["serialization"])

SUITE["csv"]["ser"]["100_ticks"]  = @benchmarkable to_csv($TICKS_100)
SUITE["csv"]["ser"]["100_orders"] = @benchmarkable to_csv($ORDERS_100)

# ─────────────────────────────────────────────────────────────────────────────
#  6.2 Deserialization
# ─────────────────────────────────────────────────────────────────────────────

SUITE["csv"]["deser"] = BenchmarkGroup(["deserialization"])

SUITE["csv"]["deser"]["100_ticks"]  = @benchmarkable from_csv(Tick, $CSV_100T)
SUITE["csv"]["deser"]["100_orders"] = @benchmarkable from_csv(Order, $CSV_100O)

# ─────────────────────────────────────────────────────────────────────────────
#  6.3 Round-trip
# ─────────────────────────────────────────────────────────────────────────────

SUITE["csv"]["roundtrip"] = BenchmarkGroup(["roundtrip"])

SUITE["csv"]["roundtrip"]["100_ticks"] = @benchmarkable from_csv(Tick, to_csv($TICKS_100))
