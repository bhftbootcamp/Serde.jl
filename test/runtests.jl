# runtests

using Serde
using Test, Dates, NanoDates, UUIDs
# To ensure that all extensions are loaded
import JSON, CSV, TOML, YAML

include("Par/Par.jl")
include("Ser/Ser.jl")
include("Utl/Macros.jl")
include("Utl/Utl.jl")
include("deser.jl")
