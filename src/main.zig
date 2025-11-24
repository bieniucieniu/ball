const std = @import("std");
const ball = @import("ball");
const buildin = @import("builtin");

const Gpa = std.heap.GeneralPurposeAllocator(.{});
pub fn main() !void {
    var gpa: Gpa = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    return ball.run(allocator);
}
