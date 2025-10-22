const std = @import("std");
const ball = @import("ball");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const allocator = gpa.allocator();
    return ball.run(allocator);
}
