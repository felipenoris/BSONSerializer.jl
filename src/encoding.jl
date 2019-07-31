
const NATIVE_BSON_DATATYPE = Union{String, Int32, Int64, DateTime, Float64, Bool, BSONObjectId}
const OTHER_NUMERIC_DATATYPE = Union{UInt8, UInt16, Int8, Int16, UInt32}

#
# Native types supported by BSON
#

function encode(val::T, ::Type{T}) where {T<:NATIVE_BSON_DATATYPE}
    val
end

function decode(val::T, ::Type{T}, m::Module) where {T<:NATIVE_BSON_DATATYPE}
    val
end

function encode_type(::Type{T}) where {T<:NATIVE_BSON_DATATYPE}
    T
end

#
# Integer numbers smaller than 32bits are encoded as Int32
#

function encode(val::T, ::Type{T}) where {T<:OTHER_NUMERIC_DATATYPE}
    Int32(val)
end

function decode(val::Int32, ::Type{T}, m::Module) where {T<:OTHER_NUMERIC_DATATYPE}
    T(val)
end

function encode_type(::Type{T}) where {T<:OTHER_NUMERIC_DATATYPE}
    Int32
end

#
# UInt64 is reinterpreted into Int64
#
function encode(val::UInt64, ::Type{UInt64})
    reinterpret(Int64, val)
end

function decode(val::Int64, ::Type{UInt64}, m::Module)
    reinterpret(UInt64, val)
end

function encode_type(::Type{UInt64})
    Int64
end

#
# Integers can be decoded to Float64
#

function decode(val::Integer, ::Type{Float64}, m::Module)
    Float64(val)
end

#
# Int32 can be decoded as Int64
#

function decode(val::Int32, ::Type{Int64}, m::Module)
    Int64(val)
end

#
# Date is encoded as DateTime with zeroed Time
#

encode(val::Date, ::Type{Date}) = DateTime(val)

decode(val::DateTime, ::Type{Date}, m::Module) = Date(val)

# accept String with standard format "yyyy-mm-dd"
decode(val::String, ::Type{Date}, m::Module) = Date(val)

encode_type(::Type{Date}) = DateTime

#
# Vectors are encoded as BSON vectors with encoded values
#

function encode(val::Vector{T}, ::Type{Vector{T}}) where {T}
    [ encode(x, T) for x in val ]
end

function decode(val::Vector, ::Type{Vector{T}}, m::Module) where {T}
    T[ decode(x, T, m) for x in val ]
end

function encode_type(val::Vector{T}) where {T}
    Vector{encode_type(T)}
end

#
# Symbols are encoded as strings
#

encode(val::Symbol, ::Type{Symbol}) = String(val)
decode(val::String, ::Type{Symbol}, m::Module) = Symbol(val)
encode_type(::Type{Symbol}) = String

#
# Char is encoded as String
#
encode(val::Char, ::Type{Char}) = string(val)
decode(val::String, ::Type{Char}, m::Module) = val[1]
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

function encode(val::T, ::Type{T}) where {T<:Union{DatePeriod, TimePeriod}}
    val.value
end

function decode(val::Int, ::Type{T}, m::Module) where {T<:Union{DatePeriod, TimePeriod}}
    T(val)
end

function encode_type(::Type{T}) where {T<:Union{DatePeriod, TimePeriod}}
    Int
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

function decode(val::Dict, ::Type{Dict{K,V}}, m::Module) where {K,V}
    decoded_dict = Dict{K,V}()
    for (k,v) in val
        decoded_dict[decode_dict_key(k, K)] = decode(val[k], V, m)
    end
    return decoded_dict
end

# encode call comming from struct field with abstract type
function encode(val::T, ::Type{A}) where {T,A}
    return BSON("type" => "$T", "value" => encode(val, T))
end

function decode(val::T, ::Type{A}, m::Module) where {T<:Union{BSONSerializer.BSON, Dict}, A}
    if haskey(val, "value")
        return decode(val["value"], m.eval(Meta.parse(val["type"])), m)
    else
        @assert haskey(val, "args")
        return decode(val, m.eval(Meta.parse(val["type"])), m)
    end
end
