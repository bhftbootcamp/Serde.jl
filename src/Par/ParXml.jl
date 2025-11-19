module ParXml

export parse_xml

using EzXML
using ..Strategy
import ..DeserSyntaxError
import ..XmlParsingStrategy
import ..default_xml_strategy

"""
    XmlSyntaxError <: Exception

Exception thrown when a [`parse_xml`](@ref) fails due to incorrect XML syntax or any underlying error that occurs during parsing.

## Fields
- `message::String`: The error message.
- `exception::Exception`: The exception that was caught.
"""
struct XmlSyntaxError <: Exception
    message::String
    exception::Union{Exception,EzXML.XMLError}
end

function Base.show(io::IO, e::XmlSyntaxError)
    return print(io, e.message, ", caused by: ", e.exception)
end


"""
    parse_xml(x::AbstractString; kw...) -> Dict{String,Any}
    parse_xml(x::Vector{UInt8}; kw...) -> Dict{String,Any}

Parse an XML string `x` (or vector of UInt8) into a dictionary.

## Keyword arguments
- `dict_type::Type{<:AbstractDict} = Dict`: The type of dictionary to return.
- `force_array::Bool = false`:
    - If `false` (default), elements with a single occurrence remain as a dictionary.
    - If `true`, all elements are converted into an array, even if only one instance exists.

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
function parse_xml end

function parse_xml(
    x::AbstractString;
    strategy::XmlParsingStrategy = default_xml_strategy(),
    dict_type::Type{D} = Dict{String,Any},
    force_array::Bool = false,
    kw...,
) where {D<:AbstractDict}
    return strategy.parser(x; dict_type = dict_type, force_array = force_array, kw...)
end

function parse_xml(x::Vector{UInt8}; strategy::XmlParsingStrategy = default_xml_strategy(), kw...)
    return parse_xml(unsafe_string(pointer(x), length(x)); strategy = strategy, kw...)
end

end
