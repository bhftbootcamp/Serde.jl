# runtests

using Serde
using Test, Dates, NanoDates, UUIDs

include("extensions.jl")

# To ensure that all extensions are loaded
import JSON, CSV, TOML, YAML, EzXML

include("Par/Par.jl")
include("Ser/Ser.jl")
include("Utl/Macros.jl")
include("Utl/Utl.jl")
include("deser.jl")
