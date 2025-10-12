const rl = @import("raylib");
const std = @import("std");
const BallsState = @import("./modules/balls/balls.zig").BallsState;
const meta = std.meta;
const bufPrint = std.fmt.bufPrint;

fn getArgsNextInt(args: *std.process.ArgIterator) !usize {
    const a = args.next() orelse return error.Null;
    return try std.fmt.parseInt(usize, std.mem.sliceTo(a, 0), 0);
}
pub fn run() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    _ = args.skip();
    const count: usize = getArgsNextInt(&args) catch 2_000;

    var state: BallsState = try .init(allocator, 1);
    defer state.deinit();

    try state.appendBalls(count);

    rl.setConfigFlags(.{ .window_resizable = true });
    rl.initWindow(state.width, state.width, "yea");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(state.loop.framerate.current);
    state.update();
    var update_thread = try std.Thread.spawn(.{}, runUpdateLoop, .{&state});
    try runRenderLoop(&state);
    update_thread.detach();
}
fn runRenderLoop(state: *BallsState) !void {
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        state.draw();
    }
}

fn runUpdateLoop(state: *BallsState) void {
    while (!rl.windowShouldClose()) {
        state.update();
        state.sleepToNext();
    }
}
