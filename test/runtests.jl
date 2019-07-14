
using Test, Dates

import Mongoc.BSON
using BSONSerializer

include("TestModule.jl")
@BSONSerializable(TestModule.ChildType)
@BSONSerializable(TestModule.FatherType)

@testset "serialize/deserialize simple type" begin

    instance = TestModule.ChildType(
        "Hello from ChildType",
        101,
        UInt8(255),
        Int8(120),
        UInt16(545),
        Int16(-12),
        DateTime(Dates.today()),
        Dates.today(),
        [Date(2019, 1, 1), Date(2019, 1, 2)])

    bson = BSONSerializer.serialize(instance)
    #println(bson)
    @test bson["type"] == "TestModule.ChildType"
    @test isa(bson["args"], Dict)
    args = bson["args"]
    @test args["c1"] == "Hello from ChildType"
    @test args["c2"] == 101
    @test args["c3"] == 255
    @test args["c4"] == 120
    @test args["c5"] == 545
    @test args["c6"] == -12
    @test args["c7"] == DateTime(Dates.today())
    @test args["c8"] == args["c7"]
    @test isa(args["c8"], DateTime)
    @test args["c9"] == [ DateTime(Date(2019, 1, 1)), DateTime(Date(2019, 1, 2)) ]

    new_instance = BSONSerializer.deserialize(bson)
    @test new_instance == instance
end

@testset "serialize/deserialize father struct" begin
    child_instance = TestModule.ChildType(
        "hey",
        101,
        UInt8(1),
        Int8(-1),
        UInt16(2),
        Int16(-2),
        DateTime(Dates.today()),
        Dates.today(),
        [Date(2019, 1, 1), Date(2019, 1, 2)])

    father_instance = TestModule.FatherType(
        "Hello from father",
        child_instance,
        [1, 2, 3])

    bson = BSONSerializer.serialize(father_instance)
    #println(bson)
    @test bson["type"] == "TestModule.FatherType"
    args = bson["args"]
    @test args["f1"] == "Hello from father"
    @test isa(args["f2"], Dict)
    @test args["f3"] == [ 1, 2, 3 ]
    child_dict = args["f2"]
    @test child_dict["type"] == "TestModule.ChildType"
    @test isa(child_dict["args"], Dict)
    child_args = child_dict["args"]
    @test child_args["c1"] == "hey"
    @test child_args["c2"] == 101
    @test child_args["c3"] == 1
    @test child_args["c4"] == -1
    @test child_args["c5"] == 2
    @test child_args["c6"] == -2
    @test child_args["c7"] == DateTime(Dates.today())
    @test child_args["c8"] == child_args["c7"]
    @test child_args["c9"] == [ DateTime(Date(2019, 1, 1)), DateTime(Date(2019, 1, 2)) ]

    new_father_instance = BSONSerializer.deserialize(bson)
    @test new_father_instance == father_instance
end

@testset "Usage" begin
    include("usage.jl")
end
