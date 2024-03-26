module SerdeJSONExt

include("Par.jl")
using .ParJson

include("De.jl")
using .DeJson

include("Ser.jl")
using .SerJson

end
