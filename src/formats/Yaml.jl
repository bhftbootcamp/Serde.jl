module SerdeYaml

export parse_yaml, from_yaml, try_from_yaml, to_yaml

import ..ParseError, ..SerdeError, ..DefaultStrategy

function parse_yaml end
function from_yaml end
function try_from_yaml end
function to_yaml end

const _YAML_HINT = "YAML support requires the `YAML` package. " *
                   "Run `import Pkg; Pkg.add(\"YAML\")` and then " *
                   "`import YAML` to activate the extension."

parse_yaml(args...; kw...)    = throw(ArgumentError(_YAML_HINT))
from_yaml(args...; kw...)     = throw(ArgumentError(_YAML_HINT))
try_from_yaml(args...; kw...) = throw(ArgumentError(_YAML_HINT))
to_yaml(args...; kw...)       = throw(ArgumentError(_YAML_HINT))

end
