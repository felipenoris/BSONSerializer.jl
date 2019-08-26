
"""
    serialize(val) :: BSON

Encodes a Julia value `val` into BSON format.

    serialize(io::IO, val)

Writes a Julia value `val` into `io` using BSON format.
"""
function serialize end

"""
    deserialize(doc::Union{BSON, Dict}; [from_module=Main])
    deserialize(io::IO; [from_module=Main])

Decodes a BSON that was previously encoded using `BSONSerializer.serialize` method
into a Julia value.

This method also accepts a `Dict` as input, given that
you may want to decode just a portion of a BSON document.

Type information is encoded as a String in the BSON document,
so the `deserialize` method uses `m.eval` to convert that to a Julia type,
where `m` is the 2nd argument of the `deserialize` method.

Regarding the optional `from_module` parameter,
it is optional for `deserialize` on a document,
but must be supplied when using `deserialize`
passing a `serializable` type.
Also, the `decode` method expects a `m::Module` argument.

```
deserialize(bson; from_module::Module=Main)
deserialize(bson, serializable, m::Module)
decode(val, type, m::Module)
```
"""
function deserialize end

function serialize(val::T) :: BSON where {T}
    return serialize(Serializable(val))
end

function serialize(val::Serializable{T}) where {T}
    error("Call @BSONSerializable($T) to generate serialize code for $T.")
end

# based on BSON.jl
resolve_typepath(fs::Vector, from_module::Module) = foldl((m, f) -> getfield(m, Symbol(f)), fs; init = from_module)

function deserialize(bson::Union{BSON, Dict}; from_module::Module=Main)
    @assert haskey(bson, "type") && haskey(bson, "args")
    datatype = resolve_typepath(bson["type"], from_module)
    @assert isa(datatype, DataType)
    return deserialize(bson, Serializable{datatype}, from_module)
end

"""
    roundtrip(val:::T) :: T

Applies `serialize` and `deserialize` to `val`.
Useful for testing.
"""
function roundtrip(val::T; from_module::Module=Main) where {T}
    return deserialize(serialize(Serializable(val)), Serializable{T}, from_module)
end

function serialize(io::IO, val::T) where {T}
	write(io, serialize(val))
end

function deserialize(io::IO; from_module=Module=Main)
	return deserialize(read(io, BSON), from_module=from_module)
end

@BSONSerializable(Missing)
@BSONSerializable(Nothing)
