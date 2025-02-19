const std = @import("std");

const PrintError = error{
    FieldNamePrint,
    ValuePrint,
    UnknownTypePrint,
    IndentPrint,
};

fn handlePrintError(err: anyerror, context: []const u8) void {
    std.debug.print("Error while printing {s}: {s}\n", .{ context, @errorName(err) });
    std.process.exit(1);
}

fn printIndent(writer: anytype, indent_level: usize) PrintError!void {
    for (indent_level) |_| {
        try printValue(writer, "    ", .{}, "indent");
    }
}

fn printValue(writer: anytype, comptime fmt: []const u8, args: anytype, context: []const u8) PrintError!void {
    writer.print(fmt, args) catch |err| {
        handlePrintError(err, context);
        return PrintError.ValuePrint;
    };
}

fn printObjectWithIndent(writer: anytype, obj: anytype, indent_level: usize) PrintError!void {
    const objType = @TypeOf(obj);

    // Ensure obj is not a primitive type
    if (@typeInfo(objType) != .Struct) {
        switch (@typeInfo(objType)) {
            .Void => try printValue(writer, "void\n", .{}, "void value"),
            .Bool => try printValue(writer, "{}\n", .{obj}, "boolean value"),
            .Int => try printValue(writer, "{d}\n", .{obj}, "integer value"),
            .Float => try printValue(writer, "{d:.2}\n", .{obj}, "float value"),
            .Pointer => {
                const ptrType = @typeInfo(objType).Pointer;
                if (ptrType.size == .Slice) {
                    if (@TypeOf(obj) == []const u8) {
                        try printValue(writer, "{s}\n", .{obj}, "string value");
                    } else {
                        try printSliceValue(writer, obj);
                    }
                } else {
                    try printPointerValue(writer, obj, objType);
                }
            },
            .Array => try printArrayValue(writer, obj, indent_level),
            .Enum => try printValue(writer, "{s}\n", .{@tagName(obj)}, "enum value"),
            .Union => try printUnionValue(writer, obj),
            .Optional => try printOptionalValue(writer, obj),
            else => try printValue(writer, "Unknown type\n", .{}, "unknown type"),
        }
        return;
    }

    inline for (@typeInfo(objType).Struct.fields) |field| {
        try printIndent(writer, indent_level);
        try printValue(writer, "{s}: ", .{field.name}, "field name");

        const fieldValue = @field(obj, field.name);
        switch (@typeInfo(field.type)) {
            .Void => try printValue(writer, "void\n", .{}, "void value"),
            .Bool => try printValue(writer, "{}\n", .{fieldValue}, "boolean value"),
            .Int => try printValue(writer, "{d}\n", .{fieldValue}, "integer value"),
            .Float => try printValue(writer, "{d:.2}\n", .{fieldValue}, "float value"),
            .Pointer => {
                const ptrType = @typeInfo(field.type).Pointer;
                if (ptrType.size == .Slice) {
                    if (@TypeOf(fieldValue) == []const u8) {
                        try printValue(writer, "{s}\n", .{fieldValue}, "string value");
                    } else {
                        try printSliceValue(writer, fieldValue);
                    }
                } else {
                    try printPointerValue(writer, fieldValue, field.type);
                }
            },
            .Array => try printArrayValue(writer, fieldValue, indent_level),
            .Struct => {
                try printValue(writer, "{{\n", .{}, "struct opening");
                try printObjectWithIndent(writer, fieldValue, indent_level + 1);
                try printIndent(writer, indent_level);
                try printValue(writer, "}}\n", .{}, "struct closing");
            },
            .Enum => try printValue(writer, "{s}\n", .{@tagName(fieldValue)}, "enum value"),
            .Union => try printUnionValue(writer, fieldValue),
            .Optional => try printOptionalValue(writer, fieldValue),
            else => try printValue(writer, "Unknown type\n", .{}, "unknown type"),
        }
    }
}

fn printPointerValue(writer: anytype, value: anytype, typeInfo: anytype) PrintError!void {
    switch (@typeInfo(typeInfo).Pointer.size) {
        .One => try printValue(writer, "{any}\n", .{value.*}, "pointer value"),
        .Slice => try printSliceValue(writer, value),
        .Many => try printValue(writer, "{any}\n", .{value}, "pointer array value"),
        else => try printValue(writer, "Unknown pointer type\n", .{}, "unknown pointer type"),
    }
}

fn printSliceValue(writer: anytype, slice: anytype) PrintError!void {
    try printValue(writer, "[\n", .{}, "slice opening");
    for (slice) |item| {
        try printIndent(writer, 1);
        try printValue(writer, "{{\n", .{}, "slice item opening");
        try printObjectWithIndent(writer, item, 2);
        try printIndent(writer, 1);
        try printValue(writer, "}}\n", .{}, "slice item closing");
    }
    try printIndent(writer, 0);
    try printValue(writer, "]\n", .{}, "slice closing");
}

fn printArrayValue(writer: anytype, array: anytype, indent_level: usize) PrintError!void {
    try printValue(writer, "[\n", .{}, "array opening");
    for (array) |item| {
        try printIndent(writer, indent_level + 1);
        try printValue(writer, "{any}\n", .{item}, "array item");
    }
    try printIndent(writer, indent_level);
    try printValue(writer, "]\n", .{}, "array closing");
}

fn printUnionValue(writer: anytype, unionValue: anytype) PrintError!void {
    const tag = std.meta.activeTag(unionValue);
    try printValue(writer, ".{s}: ", .{@tagName(tag)}, "union tag");
    switch (unionValue) {
        .rgb => |rgb| try printValue(writer, "{{ r: {}, g: {}, b: {} }}\n", .{ rgb.r, rgb.g, rgb.b }, "rgb value"),
        .hex, .name => |value| try printValue(writer, "{s}\n", .{value}, "string value"),
    }
}

fn printOptionalValue(writer: anytype, optionalValue: anytype) PrintError!void {
    if (optionalValue) |value| {
        switch (@TypeOf(value)) {
            []const u8 => try printValue(writer, "{s}\n", .{value}, "optional string value"),
            else => try printValue(writer, "{any}\n", .{value}, "optional value"),
        }
    } else {
        try printValue(writer, "null\n", .{}, "optional null value");
    }
}

pub fn printObjectToWriter(writer: anytype, obj: anytype) PrintError!void {
    try printObjectWithIndent(writer, obj, 0);
}

pub fn printObject(obj: anytype) void {
    const stdout = std.io.getStdOut().writer();
    printObjectToWriter(stdout, obj) catch |err| {
        handlePrintError(err, "printObject");
    };
}

pub fn captureOutput(obj: anytype, allocator: std.mem.Allocator) ![]const u8 {
    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit();

    try printObjectToWriter(list.writer(), obj);
    return list.toOwnedSlice();
}

pub fn processSlice(slice: []const u8) void {
    // Iterate over the slice
    for (slice) |item| {
        // Process each item
        std.debug.print("Item: {}\n", .{item});
    }
}
