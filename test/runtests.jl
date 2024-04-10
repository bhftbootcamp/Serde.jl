# runtests

using Serde
using Test, Dates, NanoDates, BSON

include("Ser/SerBson.jl")
include("Par/Par.jl")
include("Ser/Ser.jl")
include("Utl/Macros.jl")
include("Utl/Utl.jl")
include("deser.jl")
