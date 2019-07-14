
using BSONSerializer

struct MyType
    str::String
    num::Int
end

@BSONSerializable(MyType)

instance = MyType("hey", 101)
bson = BSONSerializer.serialize(instance)
#println(bson)

new_instance = BSONSerializer.deserialize(bson)
@assert new_instance == instance
