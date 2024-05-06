module TOML

import ..Serde

export to_toml,
       deser_toml,
       parse_toml

isnull(::Any) = false
isnull(v::Missing)::Bool = true
isnull(v::Nothing)::Bool = true

(ser_name(::Type{T}, k::Val{x})::Symbol) where {T,x} = Serde.ser_name(T, k)
(ser_value(::Type{T}, k::Val{x}, v::V)) where {T,x,V} = Serde.ser_value(T, k, v)
(ser_type(::Type{T}, v::V)) where {T,V} = Serde.ser_type(T, v)

(ser_ignore_field(::Type{T}, k::Val{x})::Bool) where {T,x} = Serde.ser_ignore_field(T, k)
(ser_ignore_field(::Type{T}, k::Val{x}, v::V)::Bool) where {T,x,V} = ser_ignore_field(T, k)

"""
    TomlSyntaxError <: Exception

Exception thrown when a [`parse_toml`](@ref) fails due to incorrect TOML syntax or any underlying error that occurs during parsing.

## Fields
- `message::String`: The error message.
- `exception::Exception`: The catched exception.
"""
struct TomlSyntaxError <: Exception
    message::String
    exception::Exception
end

Base.show(io::IO, e::TomlSyntaxError) = print(io, e.message)

"""
    deser_toml(::Type{T}, x) -> T

Creates a new object of type `T` and fill it with values from TOML formated string `x` (or vector of UInt8).

See also [`parse_toml`](@ref).

## Examples
```julia-repl
julia> struct Point
           x::Int64
           y::Int64
       end

julia> struct MyPlot
           tag::String
           points::Vector{Point}
       end

julia> toml = \"\"\"
       tag = "line"
       [[points]]
       x = 1
       y = 0
       [[points]]
       x = 2
       y = 3
       \"\"\";

julia> deser_toml(MyPlot, toml)
MyPlot("line", Point[Point(1, 0), Point(2, 3)])
```
"""
function deser_toml(args...; kwargs...)
    Serde.from_string(Val(:TOML), args...; kwargs...)
end

"""
    parse_toml(x::AbstractString) -> Dict{String,Any}
    parse_toml(x::Vector{UInt8}) -> Dict{String,Any}

Parses a TOML string `x` (or vector of UInt8) into a dictionary.

## Examples

```julia-repl
julia> toml = \"\"\"
       tag = "line"
       [[points]]
       x = 1
       y = 0
       [[points]]
       x = 2
       y = 3
       \"\"\";

julia> parse_toml(toml)
Dict{String, Any} with 3 entries:
  "tag"  => "line"
  "points" => Any[Dict{String, Any}("y"=>0, "x"=>1), Dict{String, Any}("y"=>3, "x"=>2)]
```
"""
function parse_toml(args...; kwargs...)
    Serde.parse(Val(:TOML), args...; kwargs...)
end

"""
    to_toml(data) -> String

Passes a dictionary `data` (or custom data structure) for making TOML string.

## Examples

Make TOML string from nested dictionaries.

```julia-repl
julia> data = Dict(
           "points" => [
               Dict("x" => "100", "y" => 200),
               Dict("x" => 300, "y" => 400),
           ],
           "data" => Dict("id" => 321, "price" => 600),
           "answer" => 42,
       );

julia> to_toml(data) |> println
answer = 42

[data]
price = 600
id = 321

[[points]]
y = 200
x = "100"

[[points]]
y = 400
x = 300
```

Make TOML string from custom data structures.

```julia-repl
julia> struct Point
           x::Int64
           y::Int64
       end

julia> struct MyPlot
           tag::String
           points::Vector{Point}
       end

julia> myline = MyPlot("line", Point[Point(1, 0), Point(2, 3)]);

julia> to_toml(myline) |> println
tag = "line"

[[points]]
x = 1
y = 0

[[points]]
x = 2
y = 3
```
"""
function to_toml(args...; kwargs...)
    Serde.to_string(Val(:TOML), args...; kwargs...)
end

end
