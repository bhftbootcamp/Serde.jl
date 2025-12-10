# runtests

using Serde
using Test, Dates, NanoDates, UUIDs

include("Par/Par.jl")
include("Ser/Ser.jl")
include("Strategy/Pipeline.jl")
include("DeserPipeline.jl")
include("Deser.jl")
