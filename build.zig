const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create a static library
    const lib = b.addStaticLibrary(.{
        .name = "zigprint",
        .root_source_file = b.path("src/printObject.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Install the library artifact
    b.installArtifact(lib);

    // Create a module for the library
    const zigprint_module = b.addModule("zigprint", .{
        .root_source_file = b.path("src/printObject.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add unit tests
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/test.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add the module to the unit tests
    lib_unit_tests.root_module.addImport("zigprint", zigprint_module);

    // Create a test step
    const test_step = b.step("test", "Run unit tests");
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    test_step.dependOn(&run_lib_unit_tests.step);

    // Optionally, you can create a step to build the module
    const module_step = b.step("module", "Build the zigprint module");
    const install_lib_step = b.addInstallArtifact(lib, .{}); // Pass an empty options struct
    module_step.dependOn(&install_lib_step.step);
}
