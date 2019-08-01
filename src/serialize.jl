
"""
    serialize(val) :: BSON

Encodes a Julia value `val` into BSON format.

    serialize(io::IO, val)

Writes a Julia value `val` into `io` using BSON format.
"""
function serialize end

"""
    deserialize(doc::Union{BSON, Dict}, m::Module=Main)

Decodes a BSON that was previously encoded using `BSONSerializer.serialize` method
into a Julia value.

This method also accepts a `Dict` as input, given that
you may want to decode just a portion of a BSON document.

Type information is encoded as a String in the BSON document,
so the `deserialize` method uses `m.eval` to convert that to a Julia type,
where `m` is the 2nd argument of the `deserialize` method.
"""
function deserialize end

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

"""
    roundtrip(val:::T) :: T

Applies `serialize` and `deserialize` to `val`.
Useful for testing.
"""
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
