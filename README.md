
# BSONSerializer.jl

[![License][license-img]](LICENSE)
[![travis][travis-img]][travis-url]
[![codecov][codecov-img]][codecov-url]

[license-img]: http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat-square
[travis-img]: https://img.shields.io/travis/felipenoris/BSONSerializer.jl/master.svg?logo=travis&label=Linux+/+macOS&style=flat-square
[travis-url]: https://travis-ci.org/felipenoris/BSONSerializer.jl
[codecov-img]: https://img.shields.io/codecov/c/github/felipenoris/BSONSerializer.jl/master.svg?label=codecov&style=flat-square
[codecov-url]: http://codecov.io/github/felipenoris/BSONSerializer.jl?branch=master

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

# this macro will generate
# serialize/deserialize code
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
