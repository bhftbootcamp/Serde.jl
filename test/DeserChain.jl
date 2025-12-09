using Serde
const Strategy = Serde.Strategy

@testset "DeserChain stages" begin
    calls = String[]
    struct DCUser
        id::Int
        name::String
    end

    parse_fn = (input; kw...) -> begin
        push!(calls, "parse")
        return Strategy.parse(Strategy.JsonParser(), input; kw...)
    end

    chain = Serde.DeserChain(
        parse = parse_fn;
        preprocess = [x -> (push!(calls, "preprocess"); strip(x))],
        normalize = [obj -> (push!(calls, "normalize"); obj)],
        pre_map = [obj -> begin
            push!(calls, "pre_map")
            idval = haskey(obj, "id") ? obj["id"] : nothing
            parsed_id = idval isa Integer ? idval : parse(Int, string(idval))
            return merge(Dict(obj), Dict("id" => parsed_id))
        end],
        mapper = (T, data) -> begin
            push!(calls, "mapper-default")
            return T(data["id"], get(data, "name", "user"))
        end,
        post_map = [obj -> (push!(calls, "post_map"); obj)],
        finalize = [obj -> (push!(calls, "finalize"); obj)],
    )

    Serde.append_stage!(chain, :post_map, obj -> (push!(calls, "post_map_2"); obj))
    obj = Serde.deser(chain, DCUser, " {\"id\":\"5\"} ")
    @test obj == DCUser(5, "user")
    @test calls == [
        "preprocess",
        "parse",
        "normalize",
        "pre_map",
        "mapper-default",
        "post_map",
        "post_map_2",
        "finalize",
    ]

    empty!(calls)
    Serde.replace_stage!(chain, :mapper, (T, data) -> begin
        push!(calls, "mapper")
        return T(data["id"] * 2, data["name"])
    end)
    Serde.replace_stage!(chain, :parse, nothing)
    Serde.replace_stage!(chain, :preprocess, Function[])
    obj2 = Serde.deser(chain, DCUser, Dict("id" => 3, "name" => "user"))
    @test obj2 == DCUser(6, "user")
    @test "mapper" in calls
end
