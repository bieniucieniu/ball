const Modes = @import("shared.zig").Modes;
const std = @import("std");

pub const CLI = false;

count: usize = 2_000,
help: bool = false,
mode: Modes = .none,
single_threaded: bool = true,

pub fn create(_: std.mem.Allocator, defaults: @This()) !@This() {
    std.debug.print("mock\n", .{});
    return defaults;
}
pub fn printHelp(_: std.fs.File) !void {
    return;
}
