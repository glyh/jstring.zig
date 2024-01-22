const std = @import("std");

pub fn linkPCRE(
    exe_compile: *std.Build.Step.Compile,
    jstring_dep: *std.Build.Dependency,
) void {
    exe_compile.addCSourceFile(.{
        .file = .{
            .path = jstring_dep.builder.pathFromRoot(
                jstring_dep.module("pcre_binding.c").source_file.path,
            ),
        },
        .flags = &.{"-std=c17"},
    });
    exe_compile.linkSystemLibrary2(
        "libpcre2-8",
        .{ .use_pkg_config = .yes },
    );
}

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("jstring", .{ .source_file = .{ .path = "src/jstring.zig" } });

    _ = b.addModule("pcre_binding.c", .{ .source_file = .{ .path = b.pathFromRoot("src/pcre/pcre_binding.c") } });

    const obj_pcre_binding = b.addObject(.{
        .name = "pcre_binding",
        .target = target,
        .optimize = optimize,
    });
    obj_pcre_binding.addCSourceFile(.{ .file = .{ .path = "src/pcre/pcre_binding.c" }, .flags = &.{"-std=c17"} });
    obj_pcre_binding.linkSystemLibrary2("libpcre2-8", .{ .use_pkg_config = .yes });

    const jstring_lib = b.addStaticLibrary(.{
        .name = "jstring",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/jstring.zig" },
        .target = target,
        .optimize = optimize,
    });
    jstring_lib.addObject(obj_pcre_binding);
    jstring_lib.linkSystemLibrary2("libpcre2-8", .{ .use_pkg_config = .yes });
    // lib.linkSystemLibraryName("libpcre2-8");

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).
    b.installArtifact(jstring_lib);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    // const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    // run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    // if (b.args) |args| {
    //     run_cmd.addArgs(args);
    // }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    // const run_step = b.step("run", "Run the app");
    // run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/jstring.zig" },
        .target = target,
        .optimize = optimize,
    });
    lib_unit_tests.addObject(obj_pcre_binding);
    lib_unit_tests.linkSystemLibrary2("libpcre2-8", .{ .use_pkg_config = .yes });
    var run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    // const exe_unit_tests = b.addTest(.{
    //     .root_source_file = .{ .path = "src/main.zig" },
    //     .target = target,
    //     .optimize = optimize,
    // });

    // const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    // test_step.dependOn(&run_exe_unit_tests.step);
}
