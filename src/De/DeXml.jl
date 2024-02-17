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
julia> struct Person
           attr::String
           name::String
           age::Int64
       end

julia> struct Content
           person::Person
           cars::Vector
       end

julia> struct Root
           root::Content
           version::String
       end

julia> xml = \"\"\"
       <?xml version="1.0"?>
       <root>
       <person attr="human">
           <name>John</name>
           <age>30</age>
       </person>
       <cars>Audi</cars>
       <cars>VW</cars>
       <cars>Skoda</cars>
       </root>
       \"\"\";

julia> deser_xml(Content, xml)
Content(Person("human", "John", 30), Any["Audi", "VW", "Skoda"])

Adding the ground key argument allows to get XML declaration.  An appropriate structure must be provided for correct deserialization procedure.

julia> deser_xml(Root, xml; decl_struct=true)
Root(Content(Person("human", "John", 30), Any["Audi", "VW", "Skoda"]), "1.0")
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
