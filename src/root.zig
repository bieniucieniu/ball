const rl = @import("raylib");
const std = @import("std");
const LoopState = @import("./modules/shared/loop/loop.zig");
const BallsState = @import("./modules/free-moving-balls/main.zig");
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

    var loopState: LoopState = .init();
    var state: BallsState = try .init(allocator, 1);
    defer state.deinit();

    try state.appendBalls(count);

    rl.setConfigFlags(.{ .window_resizable = true });
    rl.initWindow(state.width, state.width, "yea");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(loopState.framerate.current);
    state.update(loopState.delta);
    var update_thread = try std.Thread.spawn(.{}, runUpdateLoop, .{ &loopState, &state });
    defer update_thread.detach();
    try runRenderLoop(&loopState, &state);
}
fn runRenderLoop(loop: *LoopState, state: *BallsState) !void {
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();
        state.draw(loop);
    }
}

fn runUpdateLoop(loop: *LoopState, state: *BallsState) void {
    while (!rl.windowShouldClose()) {
        loop.update();
        state.update(loop.delta);
        loop.sleepToNext();
    }
}
