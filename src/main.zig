const std = @import("std");
const ball = @import("ball");
const buildin = @import("builtin");

const Gpa = std.heap.GeneralPurposeAllocator(.{});
pub fn main() !void {
    var gpa: Gpa = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var pool: std.Thread.Pool = undefined;
    try pool.init(.{
        .allocator = allocator,
    });
    defer pool.deinit();

    return ball.run(allocator, &pool);
}
