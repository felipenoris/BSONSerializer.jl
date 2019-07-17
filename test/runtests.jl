
using Test, Dates

using Mongoc: BSON, BSONObjectId
using BSONSerializer

include("TestModule.jl")
@BSONSerializable(TestModule.ChildType)
@BSONSerializable(TestModule.FatherType)
@BSONSerializable(TestModule.ManyDicts)
@BSONSerializable(TestModule.Periods)
@BSONSerializable(TestModule.SingletonStruct)
@BSONSerializable(TestModule.Option)
@BSONSerializable(TestModule.DateEncodedAsString)
@BSONSerializable(TestModule.Submodule.SubStruct)
@BSONSerializable(TestModule.StructFloat)

function encode_roundtrip(v::T) where {T}
    BSONSerializer.decode(BSONSerializer.encode(v), T)
end

@testset "encode" begin
    let
        d = Dict{String, Int}("a" => 1, "b" => 2)
        new_d = encode_roundtrip(d)
        @test new_d == d
    end
end

@testset "serialize structs" begin
    @testset "ChildType" begin
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

    @testset "FatherType" begin
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

        oid = BSONObjectId()

        father_instance = TestModule.FatherType(
            "Hello from father",
            child_instance,
            [1, 2, 3],
            oid,
            :sym)

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
        @test args["f4"] == oid
        @test args["f5"] == "sym"

        new_father_instance = BSONSerializer.deserialize(bson)
        @test new_father_instance == father_instance
    end

    @testset "Periods" begin
        instance = TestModule.Periods(Year(2000), Month(12), Day(20), Hour(23), Minute(59))
        new_instance = BSONSerializer.roundtrip(instance)
        @test new_instance == instance
    end

    @testset "ManyDicts" begin
        instance = TestModule.ManyDicts(
            Dict(:today => Dates.today(), :tomorrow => (Dates.today() + Dates.Day(1))),
            Dict(1 => Year(2000), 2 => Year(2001)),
            Dict(1 => TestModule.Periods(Year(2000), Month(10), Day(1), Hour(20), Minute(20))))
        new_instance = BSONSerializer.roundtrip(instance)
        @test new_instance == instance
    end

    @testset "SingletonStruct" begin
        instance = TestModule.SingletonStruct()
        new_instance = BSONSerializer.roundtrip(instance)
        @test new_instance == instance
    end

#=
    @testset "Option" begin
        instance = TestModule.Option(1)
        new_instance = BSONSerializer.roundtrip(instance)
        @test new_instance == instance
    end
=#

    @testset "DateEncodedAsString" begin
        instance = TestModule.DateEncodedAsString(Date(2019,12,25))
        bson_with_str = BSON("""
{
    "type" : "TestModule.DateEncodedAsString",
    "args" : {
        "date" : "2019-12-25"
    }
}
""")
        new_instance = BSONSerializer.deserialize(bson_with_str)
        @test new_instance == instance
    end

    @testset "Submodule" begin
        instance = TestModule.Submodule.SubStruct(1)
        new_instance = BSONSerializer.roundtrip(instance)
        @test new_instance == instance
    end

    @testset "decode Int as Float" begin
        bson = BSON("""
{
    "type" : "TestModule.StructFloat",
    "args" : {
        "val" : 10
    }
}
""")
        new_instance = BSONSerializer.deserialize(bson)
        @test new_instance.val == 10
        @test isa(new_instance.val, Float64)
    end
end

@testset "Usage" begin
    include("usage.jl")
end
