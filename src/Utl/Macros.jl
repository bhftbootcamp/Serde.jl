# Utl/Macros

function chain(::Val{Symbol("@default_value")}, struct_name::Symbol, field_key::String, default_value::Any)::Expr
    return quote
        function Serde.default_value(::Type{T}, ::Val{Symbol($field_key)}) where {T<:$struct_name}
            return $default_value
        end
    end
end

function chain(::Val{Symbol("@de_name")}, struct_name::Symbol, field_key::String, de_custom_name::Any)::Expr
    return quote
        function Serde.custom_name(::Type{T}, ::Val{Symbol($field_key)}) where {T<:$struct_name}
            return $de_custom_name
        end
    end
end

function chain(::Val{Symbol("@ser_json_name")}, struct_name::Symbol, field_key::String, ser_custom_name::Any)::Expr
    return quote
        function Serde.SerJson.ser_name(::Type{T}, ::Val{Symbol($field_key)}) where {T<:$struct_name}
            return $ser_custom_name
        end
    end
end

"""
    @serde decorators... typedef

Helper macro that implements user friendly configuration of the (de)serialization process (see extended [deserialization](@ref ex_deser) and [serialization](@ref ex_ser)).
Available `decorators`:
- `@default_value`: Used to define default values for fields of declared type (see [`Serde.default_value`](@ref)).
- `@de_name`: Used to defines an alias names for fields of declared type (see [`Serde.custom_name`](@ref)).
- `@ser_json_name`: Used to define custom output name for fields of declared type (see [`Serde.ser_name`](@ref ser_name)).
Next, the syntax template looks like this:
```julia
@serde @decor_1 @decor_2 ... struct
    var::T | val_1 | val_2 | ...
    ...
end
```
Any combination of available decorators is valid.
Decorators must be placed between `@serde` and `struct` keyword.
Decorator values belonging to a certain field must be separated by the `|` symbol.


## Examples
```julia
@serde @default_value @de_name @ser_json_name mutable struct Foo
    bar::Int64 | 1 | "first" | "bar"
    baz::Int64 | 2 | "baz"   | "second"
end
```
If we do not specify any value, it will be taken from the column corresponding to `@default_value`.
Notice that bar was initialised with default 1.
```julia-repl
julia> deser_json(Foo, \"\"\"{"baz": 20}\"\"\")
Foo(1, 20)
```
Also, now names from the `@de_name` column will be used for deserialization.
```julia-repl
julia> deser_json(Foo, \"\"\"{"first": 30}\"\"\")
Foo(30, 2)
```
Names from the `@ser_json_name` column will be used as output names for serialization.
```julia-repl
julia> to_json(Foo(40, 50)) |> print
{"bar":40,"second":50}
```
"""
macro serde(expr)
    expr isa Expr && (expr.head === :struct || expr.head === :macrocall) ||
        error("invalid usage of @serde")

    extract_name(args::Symbol) = args
    extract_name(args::Expr) = extract_name(args.args[1])

    serde_decorators, expr = find_serde_decorators!(expr)

    struct_type::Union{Symbol,Expr} = expr.args[2]
    struct_name::Symbol = extract_name(expr.args[2])

    struct_body::Expr = expr.args[3]
    serde_methods = Expr[]

    field_symbols = extract_field_symbols.(struct_body.args)
    field_symbols = [field_symbols[i] for i in 2:2:length(field_symbols)]

    struct_constructor = quote
        $(field_symbols...)
        function $(struct_name)(args...)
            new(args...)
        end
    end

    push!(serde_methods, esc(quote
        $(Expr(:struct, expr.args[1], struct_type, struct_constructor))
        ClassType(::Type{T}) where {T<:$struct_name} = CustomType()
    end))

    params = extract_chain_args.(struct_body.args)
    params = [params[i] for i in 2:2:length(params)]

    for param in params
        for (index, decorator_func) in enumerate(serde_decorators)
            push!(serde_methods, esc(chain(Val(decorator_func), struct_name, String(param[1]), param[index + 1])))
        end
    end

    return quote
        $(serde_methods...)
    end
end

function find_serde_decorators!(expr::Expr)
    decorators = Symbol[]
    while expr.args[1] isa Symbol
        push!(decorators, expr.args[1])
        expr = expr.args[end]
    end
    return decorators, expr
end

function extract_chain_args(definition_expr::LineNumberNode)::Vector{Symbol}
    return Symbol[]
end

function extract_chain_args(field_expr::Expr)
    field_args = Any[]
    if field_expr.head == :call && field_expr.args[1] == :|
        append!(field_args, extract_chain_args(field_expr.args[2]))
    elseif field_expr.head == :(::)
        return push!(field_args, field_expr.args[1])
    else
        return field_args
    end
    return push!(field_args, field_expr.args[end])
end

function extract_field_symbols(definition_expr::LineNumberNode)::Nothing
    return nothing
end

function extract_field_symbols(field_expr::Expr)::Expr
    while length(field_expr.args) == 3
        field_expr = field_expr.args[2]
    end
    return field_expr
end
