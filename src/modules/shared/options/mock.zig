const Modes = @import("shared.zig").Modes;
const std = @import("std");

pub const CLI = false;

count: usize = 2_000,
help: bool = false,
mode: Modes = .none,

pub fn create(_: std.mem.Allocator, defaults: @This()) !@This() {
    return defaults;
}
pub fn printHelp(_: std.fs.File) !void {
    return;
}
