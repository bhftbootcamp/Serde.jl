module DeXml

export deser_xml

using ..ParXml
import ..to_deser

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
function deser_xml(::Type{T}, x; kw...) where {T}
    return to_deser(T, parse_xml(x; kw...))
end

deser_xml(::Type{Nothing}, _) = nothing
deser_xml(::Type{Missing}, _) = missing

function deser_xml(f::Function, x; kw...)
    object = parse_xml(x; kw...)
    return to_deser(f(object), object)
end

end
