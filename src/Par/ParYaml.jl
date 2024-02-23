module ParYaml

export YamlSyntaxError
export parse_yaml

using YAML

"""
    YamlSyntaxError <: Exception

Exception thrown when a [`parse_yaml`](@ref) fails due to incorrect YAML syntax or any underlying error that occurs during parsing.

## Fields
- `message::String`: The error message.
- `exception::Exception`: The catched exception.
"""
struct YamlSyntaxError <: Exception
    message::String
    exception::YAML.ParserError
end

Base.show(io::IO, e::YamlSyntaxError) = print(io, e.message)

"""
    parse_yaml(x::AbstractString; kw...) -> Dict{String,Any}
    parse_yaml(x::Vector{UInt8}; kw...) -> Dict{String,Any}

Parse a YAML string `x` (or vector of UInt8) into a dictionary.

## Keyword arguments
You can see additional keyword arguments in YAML.jl package [repository](https://github.com/JuliaData/YAML.jl).

## Examples

```julia-repl
julia> yaml = \"\"\"
        string: qwerty
        date: 2024-01-01
        dict:
          dict_key_1: dict_value_1 #comment
          dict_key_2: dict_value_2
        list:
          - string: foo
            quoted: 'bar'
            float: 1.63
            int: 63
          - string: baz
            braces: '{{ dd }}'
        anchorTest: &myAnchor
          toSingleLine: >
            this text will be considered on a
            single line
          toMultiline: |
            this text will be considered
            on multiple lines
        aliasTest: *myAnchor
        \"\"\";

julia> parse_yaml(yaml)
Dict{String, Any} with 6 entries:
  "dict"       => Dict{String, Any}("dict_key_2"=>"dict_value_2", "dict_key_1"=>"dict_value_1")
  "string"     => "qwerty"
  "list"       => Dict{String, Any}[Dict("int"=>63, "string"=>"foo", "quoted"=>"bar", "float"=>1.63), Dict("string"=>"baz", "braces"=>"{{ dd }}")]
  "anchorTest" => Dict{String, Any}("toMultiline"=>"this text will be considered \non multiple lines\n", "toSingleLine"=>"this text will be considered on a single line\n")
  "aliasTest"  => Dict{String, Any}("toMultiline"=>"this text will be considered \non multiple lines\n", "toSingleLine"=>"this text will be considered on a single line\n")
  "date"       => Date("2024-01-01")
```
"""
function parse_yaml end

function parse_yaml(x::S; dict_type::Type{D} = Dict{String,Any}, kw...) where {S<:AbstractString,D<:AbstractDict}
    try
        YAML.load(x; dicttype = dict_type, kw...)
    catch e
        throw(YamlSyntaxError("invalid YAML syntax", e))
    end
end

function parse_yaml(x::Vector{UInt8}; kw...)
    return parse_yaml(unsafe_string(pointer(x), length(x)); kw...)
end

end
