
# BSONSerializer.jl

Encode/Decode your Julia structures to/from BSON.

## Requirements

* Julia v1.1

## Usage

```julia

using BSONSerializer

struct MyType
    str::String
    num::Int
end

@BSONSerializable(MyType)

instance = MyType("hey", 101)
bson = BSONSerializer.serialize(instance)
println(bson)

new_instance = BSONSerializer.deserialize(bson)
@assert new_instance == instance

```

Generated BSON:

```json
{
  "type": "MyType",
  "args": {
    "str": "hey",
    "num": 101
  }
}
```

## Alternative Packages

* [BSON.jl](https://github.com/MikeInnes/BSON.jl)
