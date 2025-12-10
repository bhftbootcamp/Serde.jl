using Serde
const Strategy = Serde.Strategy

@testset "DeserPipeline composition" begin
    calls = String[]
    struct DCUser
        id::Int
        name::String
    end

    pipe = Serde.deser_pipeline(
        x -> (push!(calls, "call strip"); strip(x)),
        Strategy.JsonParser(),
        Serde.Strategy.Custom._normalize_numbers_inplace!,
        data -> (push!(calls, "call"); data);
        mapper = (T, data) -> begin
            push!(calls, "call get")
            return T(data["id"], get(data, "name", "user"))
        end
    )

    obj = Serde.deser(pipe, DCUser, " {\"id\":\"5\"} ")

    @test obj == DCUser(5, "user")
    @test calls == ["call strip", "call", "call get"]
end

@testset "DeserPipeline with default mapper @deser_pipeline" begin
    struct DCUser2
        id::Int
        name::String
    end

    pipe = Serde.deser_pipeline(
        Strategy.JsonParser(),
        Serde.Strategy.Custom._camel_to_snake_keys!,
        Serde.Strategy.Custom._normalize_numbers_inplace!,
    )

    obj = Serde.deser(pipe, DCUser2, "{\"id\":\"3\", \"name\":\"bob\"}")
    @test obj == DCUser2(3, "bob")

    pipe2 = @deser_pipeline begin
        Strategy.JsonParser()
        data -> merge(data, Dict("name" => get(data, "name", "anon")))
    end

    obj2 = Serde.deser(pipe2, DCUser2, "{\"id\":7}")
    @test obj2 == DCUser2(7, "anon")
end
