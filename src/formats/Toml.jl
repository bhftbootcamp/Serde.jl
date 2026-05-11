module SerdeToml

export parse_toml, from_toml, try_from_toml, to_toml

import ..ParseError, ..SerdeError, ..DefaultStrategy

function parse_toml end
function from_toml end
function try_from_toml end
function to_toml end

const _TOML_HINT = "TOML support requires the `TOML` stdlib package. " *
                   "Run `import TOML` to activate the extension."

parse_toml(args...; kw...)    = throw(ArgumentError(_TOML_HINT))
from_toml(args...; kw...)     = throw(ArgumentError(_TOML_HINT))
try_from_toml(args...; kw...) = throw(ArgumentError(_TOML_HINT))
to_toml(args...; kw...)       = throw(ArgumentError(_TOML_HINT))

end
