
module BSONSerializer

using Mongoc: BSON, BSONObjectId

using Dates

export @BSONSerializable

const DATATYPE_OR_UNIONALL = Union{DataType, UnionAll}

include("types.jl")
include("encoding.jl")
include("codegen.jl")
include("serialize.jl")

end # module
