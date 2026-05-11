module SerdeParquet

export parse_parquet, from_parquet, try_from_parquet, to_parquet

import ..ParseError, ..SerdeError, ..DefaultStrategy

function parse_parquet end
function from_parquet end
function try_from_parquet end
function to_parquet end

const _PARQUET_HINT = "Parquet support requires the `Parquet2` and `Tables` packages. " *
                      "Run `import Pkg; Pkg.add([\"Parquet2\", \"Tables\"])` and then " *
                      "`import Parquet2, Tables` to activate the extension."

parse_parquet(args...; kw...)     = throw(ArgumentError(_PARQUET_HINT))
from_parquet(args...; kw...)      = throw(ArgumentError(_PARQUET_HINT))
try_from_parquet(args...; kw...)  = throw(ArgumentError(_PARQUET_HINT))
to_parquet(args...; kw...)        = throw(ArgumentError(_PARQUET_HINT))

end
