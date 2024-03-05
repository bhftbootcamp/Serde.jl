module SerdeJSONExt

include("Par.jl")
using .ParJson

include("De.jl")
using .DeJson

include("Ser.jl")
using .SerJson

export to_json
    to_pretty_json
    deser_json
    parse_json

end
