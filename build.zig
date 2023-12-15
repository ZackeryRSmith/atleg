const std = @import("std");
const os = std.os;
const mem = std.mem;
const fs = std.fs;
const OpenError = fs.Dir.OpenError;
const Step = std.build.Step;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const atleg_module = b.addModule("atleg", .{
        .source_file = .{ .path = "import.zig" },
    });

    var exe: *std.build.Step.Compile = undefined;

    // NOTE: This is my crazy way of building and running demos easily from zig build
    // for example `zig build -Demo=input` runs the input demo. The code itself is a bit
    // hacky as it's dynamic...
    const demo = b.option([]const u8, "emo", "Select a demo to compile and run");
    if (demo != null) {
        var demos = std.ArrayList([]const u8).init(b.allocator);
        defer demos.deinit();

        // get all file names in demos/
        var dir = fs.cwd().openIterableDir("demos", .{}) catch |err| {
            std.debug.print("Encountered an error while opening directory: {}", .{err});
            return;
        };
        defer dir.close();

        var it = dir.iterate();
        while (it.next() catch |err| {
            std.debug.print("Encountered an error while walking the directory: {}", .{err});
            return;
        }) |file| {
            if (file.kind != .file) {
                continue;
            }

            // cuts off "_demo.zig" from the file name
            demos.append(b.dupe(file.name[0 .. file.name.len - 9])) catch |err| {
                std.debug.print("Encountered an error while appending file.name: {}\n", .{err});
                return;
            };
        }

        // check if the demo exists
        if (!inArrayList(u8, demos.items, demo.?)) {
            std.debug.print("You have not supplied a valid demo:\n", .{});
            for (demos.items) |file| {
                std.debug.print("\t{s}\n", .{file});
            }
            return;
        }

        // this is somewhat hacky, it reassembles the test name at runtime
        const src_file = std.fmt.allocPrint(b.allocator, "demos/{s}_demo.zig", .{demo.?}) catch |err| {
            std.debug.print("Error creating execuable: {}\n", .{err});
            return;
        };
        defer b.allocator.free(src_file);

        // finally build and run the demo
        exe = b.addExecutable(
            .{
                .name = "menu",
                .root_source_file = .{ .path = src_file },
                .target = target,
                .optimize = optimize,
            },
        );
        exe.addModule("atleg", atleg_module);
        b.installArtifact(exe);
    }

    // once again like before: this is super hacky
    if (exe != undefined) {
        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());

        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);
    }
}

pub fn inArrayList(comptime T: type, haystack: [][]const T, needle: []const T) bool {
    for (haystack) |thing| {
        if (mem.eql(T, thing, needle)) {
            return true;
        }
    }
    return false;
}

fn concatRuntime(allocator: *std.mem.Allocator, one: []const u8, two: []const u8) !std.Buffer {
    var b = try std.Buffer.init(allocator, one);
    try b.append(two);
    return b;
}
