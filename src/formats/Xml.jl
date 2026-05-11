module SerdeXml

export parse_xml, from_xml, try_from_xml, to_xml

import ..ParseError, ..SerdeError, ..DefaultStrategy

function parse_xml end
function from_xml end
function try_from_xml end
function to_xml end

const _XML_HINT = "XML support requires the `EzXML` package. " *
                  "Run `import Pkg; Pkg.add(\"EzXML\")` and then " *
                  "`import EzXML` to activate the extension."

parse_xml(args...; kw...)    = throw(ArgumentError(_XML_HINT))
from_xml(args...; kw...)     = throw(ArgumentError(_XML_HINT))
try_from_xml(args...; kw...) = throw(ArgumentError(_XML_HINT))
to_xml(args...; kw...)       = throw(ArgumentError(_XML_HINT))

end
