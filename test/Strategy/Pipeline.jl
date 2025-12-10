const Strategy = Serde.Strategy
const Par = Serde.Par
const Ser = Serde.Ser

@testset "ParserPipeline basics" begin
    calls = String[]
    pipe = Par.parser_pipeline(
        x -> (push!(calls, "call strip"); strip(x)),
        Strategy.JsonParser(),
        obj -> (push!(calls, "call"); obj),
        obj -> (push!(calls, "call merge"); merge(obj, Dict("added" => true))),
    )

    result = Strategy.parse(pipe, " {\"value\":\"5\"} ")

    @test result["value"] == "5"
    @test result["added"] == true
    @test calls == ["call strip", "call", "call merge"]
end

@testset "ParserPipeline DSL and keyword threading" begin
    input_json = "{\"userName\": \"alice\", \"userAge\": \"25\", \"isActive\": true}"
    saw_tag = Ref(false)

    pipe = @parser_pipeline begin
        Strategy.JsonParser()
        Serde.Strategy.Custom._camel_to_snake_keys!
        Serde.Strategy.Custom._normalize_numbers_inplace!
        (obj; kw...) -> begin
            saw_tag[] = get(kw, :tag, nothing) == :ok
            return merge(obj, Dict("_decorated" => true))
        end
        obj -> Dict(k => v for (k, v) in obj if !startswith(string(k), "_"))
    end

    result = Strategy.parse(pipe, input_json; tag = :ok)

    @test saw_tag[]
    @test result["user_name"] == "alice"
    @test result["user_age"] == 25
    @test result["is_active"] == true
    @test !haskey(result, "_decorated")
end

@testset "SerializerPipeline composition and field filtering" begin
    struct UserRequest
        user_name::String
        user_id::Int
        password::String
        timestamp::DateTime
    end

    ser_pipe = Ser.serializer_pipeline(
        data -> begin
            fields = Dict(string(f) => getfield(data, f) for f in fieldnames(typeof(data)))
            merge(fields, Dict("_request_id" => "req_123"))
        end,
        data -> Dict(k => v for (k, v) in data if !startswith(k, "_") && k != "password"),
        Strategy.JsonSerializer()
    )

    user_data = UserRequest("alice", 456, "secret", DateTime(2023, 1, 1))
    result = Strategy.serialize(ser_pipe, user_data)

    @test occursin("\"user_name\":\"alice\"", result)
    @test occursin("\"user_id\":456", result)
    @test occursin("\"timestamp\":\"2023-01-01T00:00:00\"", result)
    @test !occursin("password", result)
    @test !occursin("_request_id", result)
end

@testset "SerializerPipeline and field function passthrough" begin
    ser_pipe = @serializer_pipeline begin
        data -> Dict(string(k) => v for (k, v) in pairs(data))
        data -> merge(data, Dict("extra" => "ok"))
        Strategy.JsonSerializer()
    end

    json = Strategy.serialize(ser_pipe, Dict("a" => 1))
    @test occursin("\"extra\":\"ok\"", json)

    struct FieldLimited
        keep::Int
        drop::Int
    end
    field_fn(::Type{FieldLimited}) = (:keep,)

    limited_pipe = Ser.serializer_pipeline(Strategy.JsonSerializer())
    limited_json = Strategy.serialize(limited_pipe, field_fn, FieldLimited(1, 2))
    @test limited_json == "{\"keep\":1}"
end
