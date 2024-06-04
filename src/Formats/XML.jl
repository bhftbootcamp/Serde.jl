module XML

import ..Serde, ..if_module

export to_xml,
       deser_xml,
       parse_xml

const EXT = :EzXML

(isnull(::Any)::Bool) = false
(isnull(v::Missing)::Bool) = true
(isnull(v::Nothing)::Bool) = true

(ser_name(::Type{T}, k::Val{x})::Symbol) where {T,x} = Serde.ser_name(T, k)
(ser_value(::Type{T}, k::Val{x}, v::V)) where {T,x,V} = Serde.ser_value(T, k, v)
(ser_type(::Type{T}, v::V)) where {T,V} = Serde.ser_type(T, v)

(ser_ignore_field(::Type{T}, k::Val{x})::Bool) where {T,x} = Serde.ser_ignore_field(T, k)
(ser_ignore_field(::Type{T}, k::Val{x}, v::V)::Bool) where {T,x,V} = ser_ignore_field(T, k)
(ser_ignore_null(::Type{T})::Bool) where {T} = true


"""
    XmlSyntaxError <: Exception

Exception thrown when a [`parse_xml`](@ref) fails due to incorrect XML syntax or any underlying error that occurs during parsing.

## Fields
- `message::String`: The error message.
- `exception::Exception`: The exception that was caught.
"""
struct XmlSyntaxError <: Exception
    message::String
    exception::Any
end

function Base.show(io::IO, e::XmlSyntaxError)
    return print(io, e.message, ", caused by: ", e.exception)
end

"""
    deser_xml(::Type{T}, x; kw...) -> T

Creates a new object of type `T` and fill it with values from XML formated string `x` (or vector of UInt8).

Keyword arguments `kw` is the same as in [`parse_xml`](@ref).

## Examples
```julia-repl
julia> struct Record
           count::Float64
       end

julia> struct Data
           id::Int64
           name::String
           body::Record
       end

julia> xml = \"\"\"
       <root>
           <id>100</id>
           <name>xml</name>
           <body>
               <count>100.0</count>
           </body>
       </root>
       \"\"\";

julia> deser_xml(Data, xml)
Data(100, "xml", Record(100.0))
```
"""
function deser_xml(args...; kwargs...)
    if_module(EXT) do mod
        Serde.from_string(mod, args...; kwargs...)
    end
end

"""
    parse_xml(x::AbstractString; kw...) -> Dict{String,Any}
    parse_xml(x::Vector{UInt8}; kw...) -> Dict{String,Any}

Parse an XML string `x` (or vector of UInt8) into a dictionary.

## Keyword arguments
- `dict_type::Type{<:AbstractDict} = Dict`: The type of the dictionary to be returned.

## Examples

```julia-repl
julia> xml = \"\"\"
           <book id="bk101">
              <title>Advanced Julia Programming</title>
              <authors>
                  <author lang="en">John Doe</author>
                  <author lang="es">Juan Pérez</author>
              </authors>
              <year>2024</year>
              <price>49.99</price>
           </book>
       \"\"\"

julia> parse_xml(xml)
Dict{String, Any} with 5 entries:
  "price"   => Dict{String, Any}("_"=>"49.99")
  "year"    => Dict{String, Any}("_"=>"2024")
  "id"      => "bk101"
  "title"   => Dict{String, Any}("_"=>"Advanced Julia Programming")
  "authors" => Dict{String, Any}("author"=>Dict{String, Any}[Dict("lang"=>"en", "_"=>"John Doe"), Dict("lang"=>"es", "_"=>"Juan Pérez")])
```
"""
function parse_xml(args...; kwargs...)
    if_module(EXT) do mod
        Serde.parse(mod, args...; kwargs...)
    end
end

"""
    to_xml(val; key::String = "xml") -> String

Serializes any nested data `val` into an XML string that follows the next rules:

- Values of **primitive types** are used as an element of the current tag.
- Vector elements will be used as sub-tag elements.
- Dictionaries are processed using the following rules:
    - Key names must be a string or a symbol types.
    - A key with a **non-empty string** value will be interpreted as a new sub-tag.
    - A key with an **empty string** value will be interpreted as an element of the current tag.
- Custom types are handled as follows:
    - The field name containing the **primitive type** will be used as an attribute for the current tag.
    - A field name containing a **composite type** (dictionary or other custom type) will be used as the name for the next sub-tag.
    - A primitive type field with **a special name "_"** will be used as an element for the current tag.

Thus, this method can serialize all basic data types and can work with any nesting level of a combination of dictionaries and custom data types.
The `key` keyword specifies the name of the root tag.

## Examples
```julia-repl
julia> struct Image
           dpi::Int64
           _::String
       end

julia> struct Data
           info::Dict
           image::Image
       end

julia> data_info = Dict("id" => "451", "status" => "OK", "_" => "employee");

julia> to_xml(Data(data_info, Image(200, "profile.png"))) |> print
<xml>
  <image dpi="200">profile.png</image>
  <info status="OK" id="451">employee</info>
</xml>
```
"""
function to_xml(args...; kwargs...)
    if_module(EXT) do mod
        Serde.to_string(mod, args...; kwargs...)
    end
end

end
