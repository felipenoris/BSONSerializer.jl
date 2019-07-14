
struct Serializable{T}
    val::T

    function Serializable(val::T) where {T}
        @assert !isbits(T) "BSONSerializer cannot serialize a bitstype to BSON."
        return new{T}(val)
    end
end
