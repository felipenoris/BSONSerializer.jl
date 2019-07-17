
module BSONSerializer

using Mongoc: BSON, BSONObjectId

using Dates

export @BSONSerializable

include("types.jl")
include("encoding.jl")
include("codegen.jl")
include("serialize.jl")

end # module
