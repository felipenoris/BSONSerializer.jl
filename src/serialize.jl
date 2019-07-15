
function serialize(val::T) :: BSON where {T}
    return serialize(Serializable(val))
end

function deserialize(bson::BSON, mod::Module=Main)
    @assert haskey(bson, "type") && haskey(bson, "args")
    datatype = mod.eval(Meta.parse(bson["type"]))
    @assert isa(datatype, DataType)
    return deserialize(bson, Serializable{datatype})
end

function roundtrip(val::T) where {T}
    return deserialize(serialize(Serializable(val)), Serializable{T})
end
