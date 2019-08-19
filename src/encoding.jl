
"""
    encode(val, source_type)

Encodes `val::T` that comes from
a struct with declared type `source_type`.

Most of the time, `T == source_type`.
But fields with abstract or union types will
display a concrete `T` type and an abstract `source_type`.
When this happens, it is necessary to pass
type information to the encoded value.
"""
function encode end

"""
    decode(val, target_type, module)

Decodes `val::T` to a field with declared type `target_type`.

`val` is the value stored in the BSON.
"""
function decode end

"""
    encode_type(T)

Reports the type used to encode a type `T` to BSON.
"""
function encode_type end

#
# Native types supported by BSON
#

for tt in (String, Int32, Int64, DateTime, Float64, Bool, BSONObjectId)
    @eval begin
            function encode(val::$tt, ::Type{$tt})
                val
            end

            function decode(val::$tt, ::Type{$tt})
                val
            end

            function encode_type(::Type{$tt})
                $tt
            end
    end
end

#
# Integer numbers smaller than 32bits are encoded as Int32
#

for tt in (UInt8, UInt16, Int8, Int16, UInt32)
    @eval begin
            function encode(val::$tt, ::Type{$tt})
                Int32(val)
            end

            function decode(val::Int32, ::Type{$tt})
                ($tt)(val)
            end

            function encode_type(::Type{$tt})
                Int32
            end
    end
end

#
# UInt64 is reinterpreted into Int64
#
function encode(val::UInt64, ::Type{UInt64})
    reinterpret(Int64, val)
end

function decode(val::Int64, ::Type{UInt64})
    reinterpret(UInt64, val)
end

function encode_type(::Type{UInt64})
    Int64
end

#
# Integers can be decoded to Float64
#

function decode(val::Integer, ::Type{Float64})
    Float64(val)
end

#
# Int32 can be decoded as Int64
#

function decode(val::Int32, ::Type{Int64})
    Int64(val)
end

#
# Date is encoded as DateTime with zeroed Time
#

encode(val::Date, ::Type{Date}) = DateTime(val)

decode(val::DateTime, ::Type{Date}) = Date(val)

# accept String with standard format "yyyy-mm-dd"
decode(val::String, ::Type{Date}) = Date(val)

encode_type(::Type{Date}) = DateTime

#
# Vectors are encoded as BSON vectors with encoded values
#

function encode(val::Vector{T}, ::Type{Vector{T}}) where {T}
    [ encode(x, T) for x in val ]
end

function decode(val::Array, ::Type{Vector{T}}) where {T}
    T[ decode(x, T) for x in val ]
end

# in case type information is not available, assume Vector
function decode(val::Array, ::Type{Array})
    T = eltype(val)
    T[ decode(x, T) for x in val ]
end

function encode_type(val::Vector{T}) where {T}
    Vector{encode_type(T)}
end

#
# Symbols are encoded as strings
#

encode(val::Symbol, ::Type{Symbol}) = String(val)
decode(val::String, ::Type{Symbol}) = Symbol(val)
encode_type(::Type{Symbol}) = String

#
# Char is encoded as String
#
encode(val::Char, ::Type{Char}) = string(val)
decode(val::String, ::Type{Char}) = val[1]
encode_type(::Type{Char}) = String

#
# Nothing / Missing
#
#=
function decode(val::T, ::Type{Union{Nothing, T}}) where {T}
    println("called decode on union{Nothing, T}")
    decode(val, T)
end
=#

#
# DatePeriod and TimePeriod are encoded as Int
#

for tt in union(InteractiveUtils.subtypes(DatePeriod), InteractiveUtils.subtypes(TimePeriod))
    @eval begin
            function encode(val::$tt, ::Type{$tt})
                val.value
            end

            function decode(val::Int64, ::Type{$tt})
                ($tt)(val)
            end

            function decode(val::Int32, ::Type{$tt})
                ($tt)(val)
            end

            function encode_type(::Type{$tt})
                Int
            end
    end
end

#
# Dictionaries with String as symbols are natively supported by BSON.
# Edge case might fail: when V is an abstract type.
#

encode_dict_key(key::String) = key
decode_dict_key(key::String, ::Type{String}) = key

encode_dict_key(key::Symbol) = String(key)
decode_dict_key(key::String, ::Type{Symbol}) = Symbol(key)

encode_dict_key(key::Integer) = string(Int(key))
function decode_dict_key(key::String, ::Type{T}) where {T<:Integer}
    T(parse(Int, key))
end

function encode(val::Dict{K,V}, ::Type{Dict{K,V}}) where {K,V}
    encoded_dict = Dict{String, encode_type(V)}()
    for (k,v) in val
        encoded_dict[encode_dict_key(k)] = encode(v, V)
    end
    return encoded_dict
end

function decode(val::Dict, ::Type{Dict{K,V}}) where {K,V}
    decoded_dict = Dict{K,V}()
    for (k,v) in val
        decoded_dict[decode_dict_key(k, K)] = decode(val[k], V)
    end
    return decoded_dict
end

# encode call comming from struct field with abstract type
function encode(val::T, ::Type{A}) where {T, A}
    @assert T != A "encode method for type $T was not provided."
    return BSON("type" => typepathref(T), "value" => encode(val, T))
end

function decode(val::T, ::Type{A}) where {T<:Union{BSONSerializer.BSON, Dict}, A}
    if haskey(val, "value")
        return decode(val["value"], resolve_typepath(val["type"]))
    elseif haskey(val, "args")
        return decode(val, resolve_typepath(val["type"]))
    elseif T == A
        error("decode method for type $T was not provided.")
    else
        error("Can't decode from value of type $T to target type $A.")
    end
end

#
# encode Functions as singletons
#

function encode(f::Function, ::Type{T}) where {T<:Function}
    return typepathref(typeof(f))
end

function decode(val::Vector, ::Type{T}) where {T<:Function}
    datatype = resolve_typepath(val)
    @assert isdefined(datatype, :instance)
    return datatype.instance
end

function encode_type(::Type{T}) where {T<:Function}
    Vector{Any}
end
