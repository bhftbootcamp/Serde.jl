const Strategy = Serde.Strategy
const Par = Serde.Par
const Ser = Serde.Ser

@testset "ParserChain stages" begin
    calls = String[]
    decoder = (input; kw...) -> begin
        push!(calls, "decode")
        return Strategy.parse(Strategy.JsonParser(), input; kw...)
    end

    chain = Par.ParserChain(
        decoder;
        preprocess = [x -> (push!(calls, "preprocess"); strip(x))],
        normalize = [obj -> (push!(calls, "normalize"); obj)],
        pre_transform = [obj -> (push!(calls, "pre_transform"); obj)],
        transform = [obj -> (push!(calls, "transform"); merge(obj, Dict("added" => true)))],
        post_transform = [obj -> (push!(calls, "post_transform"); obj)],
        finalize = [obj -> (push!(calls, "finalize"); obj)],
    )

    Serde.append_stage!(chain, :finalize, obj -> (push!(calls, "finalize-2"); obj))
    result = Strategy.parse(chain, " {\"value\":\"5\"} ")
    @test result["value"] == "5"
    @test result["added"]
    @test calls == [
        "preprocess",
        "decode",
        "normalize",
        "pre_transform",
        "transform",
        "post_transform",
        "finalize",
        "finalize-2",
    ]

    empty!(calls)
    Serde.replace_stage!(chain, :decode, x -> begin
        push!(calls, "decode-override")
        return Dict("value" => 7)
    end)
    result_override = Strategy.parse(chain, "{}")
    @test result_override["value"] == 7
    @test calls[1] == "preprocess"
    @test calls[2] == "decode-override"
end

@testset "Complex custom parser composition" begin
    input_json = "{\"userName\": \"alice\", \"userAge\": \"25\", \"isActive\": true, \"nestedData\": {\"firstName\": \"bob\", \"lastName\": \"42\"}}"

    complex_parser = Par.ParserChain(
        (input; kw...) -> Serde.parse_json(input; kw...);
        normalize = [
            Serde.Strategy.Custom._normalize_numbers_inplace!,
            Serde.Strategy.Custom._camel_to_snake_keys!
        ]
    )

    result = Strategy.parse(complex_parser, input_json)

    @test result["user_name"] == "alice"
    @test result["user_age"] == 25
    @test result["is_active"] == true
    @test result["nested_data"]["first_name"] == "bob"
    @test result["nested_data"]["last_name"] == 42

    reverse_parser = Par.ParserChain(
        (input; kw...) -> Serde.parse_json(input; kw...);
        normalize = [
            Serde.Strategy.Custom._camel_to_snake_keys!,
            Serde.Strategy.Custom._normalize_numbers_inplace!
        ]
    )

    result_reverse = Strategy.parse(reverse_parser, input_json)

    @test result_reverse["user_name"] == "alice"
    @test result_reverse["user_age"] == 25
    @test result_reverse["is_active"] == true
    @test result_reverse["nested_data"]["first_name"] == "bob"
    @test result_reverse["nested_data"]["last_name"] == 42
end

@testset "Primitive function composition chains" begin
    data_processor = Par.ParserChain(
        (input; kw...) -> Serde.parse_json(input; kw...);
        preprocess = [
            strip,
            x -> replace(x, r"\s+" => " ")
        ],
        normalize = [
            obj -> begin
                if obj isa AbstractDict
                    Dict(k => (v isa String ? uppercase(v) : v) for (k, v) in obj)
                else
                    obj
                end
            end,
            obj -> merge(obj, Dict("_processed_at" => "test_time"))
        ],
        transform = [
            obj -> Dict(k => v for (k, v) in obj if !startswith(string(k), "_")),
            obj -> merge(obj, Dict("name_length" => length(get(obj, "name", ""))))
        ]
    )

    input = "  {\"name\": \"alice\", \"age\": 25, \"city\": \"new york\"}  "
    result = Strategy.parse(data_processor, input)

    @test result["name"] == "ALICE"
    @test result["age"] == 25
    @test result["city"] == "NEW YORK"
    @test result["name_length"] == 5
    @test !haskey(result, "_processed_at")
end

@testset "Reusable composite strategy creation" begin
    function create_api_response_parser()
        return Par.ParserChain(
            (input; kw...) -> Serde.parse_json(input; kw...);
            normalize = [
                Serde.Strategy.Custom._normalize_numbers_inplace!,
                Serde.Strategy.Custom._camel_to_snake_keys!
            ],
            transform = [
                obj -> merge(obj, Dict(
                    "_response_type" => "api_data",
                    "_timestamp" => "processed"
                )),
                obj -> begin
                    if !haskey(obj, "user_id")
                        error("Missing required field: user_id")
                    end
                    obj
                end
            ],
            finalize = [
                obj -> Dict(k => v for (k, v) in obj if !startswith(string(k), "_"))
            ]
        )
    end

    api_parser = create_api_response_parser()

    valid_response = "{\"userId\": \"123\", \"userName\": \"john\", \"isVerified\": \"1\", \"metadata\": {\"createdAt\": \"2023\"}}"
    result = Strategy.parse(api_parser, valid_response)

    @test result["user_id"] == 123
    @test result["user_name"] == "john"
    @test result["is_verified"] == 1
    @test result["metadata"]["created_at"] == 2023

    invalid_response = "{\"userName\": \"jane\"}"
    @test_throws ErrorException Strategy.parse(api_parser, invalid_response)
end

@testset "Advanced serializer chain composition" begin
    api_serializer = Ser.SerializerChain(
        Strategy.JsonSerializer();
        preprocess = [
            data -> begin
                fields = Dict(string(f) => getfield(data, f) for f in fieldnames(typeof(data)))
                merge(fields, Dict(
                    "_request_id" => "req_123",
                    "_version" => "1.0"
                ))
            end,
            data -> begin
                converted = Dict{String, Any}()
                for (k, v) in data
                    if v isa DateTime
                        converted[string(k)] = string(v)
                    elseif v isa Symbol
                        converted[string(k)] = string(v)
                    else
                        converted[string(k)] = v
                    end
                end
                converted
            end
        ],
        normalize = [
            data -> Dict(k => v for (k, v) in data if k != "password"),
            data -> merge(data, Dict(
                "data_size" => length(string(data)),
                "field_count" => length(keys(data))
            ))
        ],
        transform = [
            data -> begin
                mapped = Dict{String, Any}()
                for (k, v) in data
                    if k == "user_name"
                        mapped["username"] = v
                    elseif k == "user_id"
                        mapped["userId"] = v
                    else
                        mapped[k] = v
                    end
                end
                mapped
            end
        ],
        finalize = [
            out -> replace(out, r",?\s*\"_[^\"]*\":\s*\"[^\"]*\"" => ""),
            out -> replace(out, r",\s*}" => "}")
        ]
    )

    struct UserRequest
        user_name::String
        user_id::Int
        password::String
        timestamp::DateTime
    end

    user_data = UserRequest("alice", 456, "secret", DateTime(2023, 1, 1))

    result = Strategy.serialize(api_serializer, user_data)

    @test occursin("\"username\":\"alice\"", result)
    @test occursin("\"userId\":456", result)
    @test occursin("\"timestamp\":\"2023-01-01T00:00:00\"", result)

    @test !occursin("password", result)

    @test occursin("\"data_size\":", result)
    @test occursin("\"field_count\":", result)

    @test !occursin("_request_id", result)
    @test !occursin("_version", result)
end

@testset "Bidirectional serialization/deserialization" begin
    snake_parser = Par.ParserChain(
        (input; kw...) -> Serde.parse_json(input; kw...);
        transform = [
            obj -> begin
                if obj isa AbstractDict
                    converted = Dict{String, Any}()
                    for (k, v) in obj
                        camel_key = replace(k, r"_([a-z])" => s -> uppercase(s[2]))
                        converted[camel_key] = v isa AbstractDict ? snake_parser.transform[1](v) : v
                    end
                    converted
                else
                    obj
                end
            end
        ]
    )

    camel_serializer = Ser.SerializerChain(
        Serde.JsonSerializer();
        preprocess = [
            data -> begin
                if data isa Dict
                    converted = Dict{String, Any}()
                    for (k, v) in data
                        snake_key = replace(string(k), r"([A-Z])" => s -> "_" * lowercase(s[1]))
                        converted[snake_key] = v isa Dict ? camel_serializer.preprocess[1](v) : v
                    end
                    converted
                else
                    data
                end
            end,
            data -> begin
                converted = Dict{String, Any}()
                for (k, v) in data
                    if v isa Number && !(v isa Bool) && !isnan(v) && !isinf(v)
                        converted[k] = string(v)
                    else
                        converted[k] = v
                    end
                end
                converted
            end
        ]
    )

    original_data = Dict("userName" => "alice", "userAge" => 25, "isActive" => true)

    json_str = Strategy.serialize(camel_serializer, original_data)

    @test occursin("\"user_name\":\"alice\"", json_str)
    @test occursin("\"user_age\":\"25\"", json_str)
    @test occursin("\"is_active\":true", json_str)

    parsed_back = Strategy.parse(snake_parser, json_str)

    @test parsed_back["userName"] == "alice"
    @test parsed_back["userAge"] == "25"
    @test parsed_back["isActive"] == true
end

@testset "SerializerChain stages" begin
    calls = String[]
    writer_chain = Ser.SerializerChain(
        Strategy.JsonSerializer();
        preprocess = [data -> (push!(calls, "preprocess"); merge(Dict(data), Dict("raw" => true)))],
        normalize = [data -> (push!(calls, "normalize"); data)],
        transform = [data -> (push!(calls, "transform"); data)],
        prewrite = [data -> (push!(calls, "prewrite"); data)],
        postwrite = [out -> (push!(calls, "postwrite"); out)],
        finalize = [out -> (push!(calls, "finalize"); out)],
    )

    Serde.append_stage!(writer_chain, :transform, data -> begin
        push!(calls, "transform-2")
        return merge(Dict(data), Dict("extra" => "ok"))
    end)
    result = Strategy.serialize(writer_chain, Dict("a" => 1))
    @test occursin("\"extra\":\"ok\"", result)
    @test calls == ["preprocess", "normalize", "transform", "transform-2", "prewrite", "postwrite", "finalize"]

    empty!(calls)
    Serde.replace_stage!(writer_chain, :writer, data -> begin
        push!(calls, "custom-writer")
        return "out=$(get(data, "a", nothing))"
    end)
    custom_result = Strategy.serialize(writer_chain, Dict("a" => 2))
    @test custom_result == "out=2"
    @test "custom-writer" in calls

    empty!(calls)
    struct FieldLimited
        keep::Int
        drop::Int
    end
    field_fn(::Type{FieldLimited}) = (:keep,)

    field_chain = Ser.SerializerChain(Strategy.JsonSerializer())
    json = Strategy.serialize(field_chain, field_fn, FieldLimited(1, 2))
    @test json == "{\"keep\":1}"
end
