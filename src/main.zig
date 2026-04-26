const std = @import("std");
const ball = @import("ball");
const buildin = @import("builtin");

const Gpa = std.heap.DebugAllocator(.{});
pub fn main(init: std.process.Init) !void {
    var gpa: Gpa = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    return ball.run(io, allocator, init.minimal.args);
}
