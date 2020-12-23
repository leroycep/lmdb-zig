const Builder = @import("std").build.Builder;
const deps = @import("./deps.zig");

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const lib = b.addStaticLibrary("lmdb", "src/lib.zig");
    lib.setBuildMode(mode);
    deps.addAllTo(lib);
    lib.install();

    var main_tests = b.addTest("src/test.zig");
    deps.addAllTo(main_tests);
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);

    // Build/run examples
    {
        // Please don't use this code as a reference for adding LMDB as dependency.
        // We can't add lmdb-zig as a dependency of this project via zigmod, so this
        // code manually works around that.
        var example = b.addExecutable("example-simple", "examples/simple.zig");
        deps.addAllTo(example);
        example.addPackage(.{ .name = "lmdb", .path = "src/lib.zig", .dependencies = deps.packages });
        example.setBuildMode(mode);

        const example_step = b.step("run-example-simple", "Run the example");
        example_step.dependOn(&example.run().step);
    }
}
