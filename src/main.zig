const std = @import("std");
const ball = @import("ball");
const buildin = @import("builtin");

const Gpa = std.heap.GeneralPurposeAllocator(.{});
pub fn main() !void {
    var gpa: Gpa = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    return if (buildin.single_threaded) ball.runSingleThreaded(allocator) else ball.run(allocator);
}
