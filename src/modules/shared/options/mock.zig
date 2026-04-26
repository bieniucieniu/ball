const Modes = @import("shared.zig").Modes;
const std = @import("std");

pub const CLI = false;

count: usize = 2_000,
help: bool = false,
mode: Modes = .none,
single_threaded: bool = false,

pub fn create(s: @This()) !@This() {
    std.debug.print("mock\n", .{});
    return s;
}
pub fn printHelp(_: std.Io, _: std.fs.File) !void {
    return;
}
