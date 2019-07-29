
function serialize(val::T) :: BSON where {T}
    return serialize(Serializable(val))
end

function serialize(val::Serializable{T}) where {T}
    error("Call @BSONSerializable($T) to generate serialize code for $T.")
end

function deserialize(bson::Union{BSON, Dict}, m::Module=Main)
    @assert haskey(bson, "type") && haskey(bson, "args")
    datatype = m.eval(Meta.parse(bson["type"]))
    @assert isa(datatype, DataType)
    return deserialize(bson, Serializable{datatype}, m)
end

function roundtrip(val::T) where {T}
    return deserialize(serialize(Serializable(val)), Serializable{T})
end

function serialize(io::IO, val::T) where {T}
	write(io, serialize(val))
end

function deserialize(io::IO, m::Module=Main)
	return deserialize(read(io, BSON), m)
end

@BSONSerializable(Missing)
@BSONSerializable(Nothing)
