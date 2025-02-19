const std = @import("std");
const testing = std.testing;
const captureOutput = @import("zigprint.zig").captureOutput;

// Test types
const Color = enum {
    Red,
    Green,
    Blue,
    Custom,
};

const ColorValue = union(enum) {
    rgb: struct { r: u8, g: u8, b: u8 },
    hex: []const u8,
    name: []const u8,
};

const Address = struct {
    street: []const u8,
    number: u16,
    city: []const u8,
    country: []const u8,
};

const Course = struct {
    id: u32,
    name: []const u8,
    credits: u8,
    active: bool,
};

const Student = struct {
    id: u32,
    name: []const u8,
    age: u16,
    address: Address,
    favorite_color: Color,
    color_value: ColorValue,
    grades: [3]f32,
    courses: [2]Course,
    mentor_name: ?[]const u8,
    graduation_year: ?u16,
    void_field: void,
    ref_count: *const u32,
    data_ptr: [*]const u8,
};

fn runTest(obj: anytype, expected: []const u8) !void {
    const output = try captureOutput(obj, testing.allocator);
    defer testing.allocator.free(output);
    try testing.expectEqualStrings(expected, output);
}

test "simple value printing" {
    var integer: u32 = 10;
    const void_value: void = {};
    const null_value: ?u32 = null;
    const boolean: bool = true;
    const float_value: f32 = 10.5;
    const pointer_value: *u32 = &integer;
    const array_value: [3]u32 = .{ 1, 2, 3 };
    const enum_value: Color = Color.Red;
    const union_value: ColorValue = ColorValue{ .rgb = .{ .r = 255, .g = 128, .b = 0 } };
    const optional_value: ?[]const u8 = "present";

    try runTest(integer, "10\n");
    try runTest(void_value, "void\n");
    try runTest(null_value, "null\n");
    try runTest(boolean, "true\n");
    try runTest(float_value, "10.50\n");
    try runTest(pointer_value, "10\n");
    try runTest(array_value, "[\n    1\n    2\n    3\n]\n");
    try runTest(enum_value, "Red\n");
    try runTest(union_value, ".rgb: { r: 255, g: 128, b: 0 }\n");
    try runTest(optional_value, "present\n");
}

test "simple struct printing" {
    const SimpleStruct = struct {
        id: u32,
        name: []const u8,
    };

    const obj = SimpleStruct{
        .id = 1,
        .name = "test",
    };

    try runTest(obj, "id: 1\nname: test\n");
}

test "enum printing" {
    const TestStruct = struct {
        color: Color,
    };

    const obj = TestStruct{ .color = .Red };
    try runTest(obj, "color: Red\n");
}

test "union printing" {
    const TestStruct = struct {
        color: ColorValue,
    };

    const obj = TestStruct{
        .color = ColorValue{ .rgb = .{ .r = 255, .g = 128, .b = 0 } },
    };
    try runTest(obj, "color: .rgb: { r: 255, g: 128, b: 0 }\n");
}

test "optional values" {
    const TestStruct = struct {
        maybe_string: ?[]const u8,
        maybe_int: ?u32,
    };

    const obj = TestStruct{
        .maybe_string = "present",
        .maybe_int = null,
    };
    try runTest(obj, "maybe_string: present\nmaybe_int: null\n");
}

test "array printing" {
    const TestStruct = struct {
        numbers: [3]u32,
    };

    const obj = TestStruct{
        .numbers = .{ 1, 2, 3 },
    };
    try runTest(obj, "numbers: [\n    1\n    2\n    3\n]\n");
}

test "nested struct printing" {
    const TestStruct = struct {
        address: Address,
    };

    const obj = TestStruct{
        .address = .{
            .street = "Test St",
            .number = 123,
            .city = "Test City",
            .country = "Test Country",
        },
    };
    try runTest(obj, "address: {\n    street: Test St\n    number: 123\n    city: Test City\n    country: Test Country\n}\n");
}

test "complex student struct" {
    var ref_count: u32 = 1;
    const data = "some data";

    const student = Student{
        .id = 12345,
        .name = "John Doe",
        .age = 20,
        .address = .{
            .street = "Main Street",
            .number = 123,
            .city = "Springfield",
            .country = "USA",
        },
        .favorite_color = Color.Custom,
        .color_value = ColorValue{ .rgb = .{ .r = 255, .g = 128, .b = 0 } },
        .grades = .{ 85.5, 92.0, 78.5 },
        .courses = .{
            .{
                .id = 101,
                .name = "Mathematics",
                .credits = 3,
                .active = true,
            },
            .{
                .id = 102,
                .name = "Physics",
                .credits = 4,
                .active = false,
            },
        },
        .mentor_name = "Dr. Smith",
        .graduation_year = null,
        .void_field = {},
        .ref_count = &ref_count,
        .data_ptr = data,
    };

    const output = try captureOutput(student, testing.allocator);
    defer testing.allocator.free(output);

    // Test the complete output structure
    try testing.expect(std.mem.startsWith(u8, output, "id: 12345\n"));
    try testing.expect(std.mem.indexOf(u8, output, "name: John Doe\n") != null);
    try testing.expect(std.mem.indexOf(u8, output, "age: 20\n") != null);
    try testing.expect(std.mem.indexOf(u8, output, "favorite_color: Custom\n") != null);
}

test "trial" {
    const Country = enum {
        Turkey,
        USA,
        Germany,
    };

    const User = struct {
        name: []const u8,
        age: u32,
        country: Country,
    };

    const Room = struct {
        name: []const u8,
        users: []const User,
    };

    const user = User{
        .name = "Burak",
        .age = 25,
        .country = Country.Turkey,
    };

    const room = Room{
        .name = "Living Room",
        .users = &[_]User{user},
    };

    try runTest(room, "name: Living Room\nusers: [\n    {\n        name: Burak\n        age: 25\n        country: Turkey\n    }\n]\n");
}
