const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .Debug });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "zck3",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Grammar
    const grammar_mod = b.createModule(.{
        .root_source_file = b.path("src/grammars/grammar.zig"),
        .target = target,
        .optimize = optimize,
    });

    const grammar_lib = b.addStaticLibrary(.{
        .name = "grammar",
        .root_module = grammar_mod,
    });

    b.installArtifact(grammar_lib);

    // LR

    const lr_mod = b.createModule(.{
        .root_source_file = b.path("src/lr/automaton.zig"),
        .target = target,
        .optimize = optimize,
    });

    lr_mod.addImport("grammar", grammar_mod);

    const lr_lib = b.addStaticLibrary(.{
        .name = "lr",
        .root_module = lr_mod,
    });

    b.installArtifact(lr_lib);

    const test_step = b.step("test", "Run unit tests");
    const test_filter = b.option([]const []const u8, "test-filter", "Filter for test");

    const exe_unit_tests = b.addTest(.{
        .name = "exe-tests",
        .root_module = exe_mod,
        .filters = test_filter orelse &.{},
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const lr_unit_tests = b.addTest(.{
        .name = "lr-tests",
        .root_module = lr_mod,
        .filters = test_filter orelse &.{},
    });

    const run_lr_unit_tests = b.addRunArtifact(lr_unit_tests);

    const grammar_test = b.addTest(.{
        .name = "grammar-tests",
        .root_module = grammar_mod,
        .filters = test_filter orelse &.{},
    });

    const run_grammar_test = b.addRunArtifact(grammar_test);

    test_step.dependOn(&run_exe_unit_tests.step);
    test_step.dependOn(&run_grammar_test.step);
    test_step.dependOn(&run_lr_unit_tests.step);
}
