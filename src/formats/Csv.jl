module SerdeCsv

export parse_csv, from_csv, try_from_csv, to_csv

import ..ParseError, ..SerdeError, ..DefaultStrategy

function parse_csv end
function from_csv end
function try_from_csv end
function to_csv end

const _CSV_HINT = "CSV support requires the `CSV` package. " *
                  "Run `import Pkg; Pkg.add(\"CSV\")` and then " *
                  "`import CSV` to activate the extension."

parse_csv(args...; kw...)    = throw(ArgumentError(_CSV_HINT))
from_csv(args...; kw...)     = throw(ArgumentError(_CSV_HINT))
try_from_csv(args...; kw...) = throw(ArgumentError(_CSV_HINT))
to_csv(args...; kw...)       = throw(ArgumentError(_CSV_HINT))

end
