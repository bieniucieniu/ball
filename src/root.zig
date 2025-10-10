const rl = @import("raylib");
const rg = @import("raygui");
const std = @import("std");
const BallState = @import("./entities/ball.zig").BallState;
const LoopState = @import("./loop.zig").LoopState;
const GameState = @import("./game.zig").GameState;
const meta = std.meta;
const bufPrint = std.fmt.bufPrint;

pub fn run() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const allocator = gpa.allocator();
    var state: GameState = try .init(allocator, 1);
    defer state.deinit();

    try state.appendBalls(200_000);

    rl.setConfigFlags(.{ .window_resizable = true });
    rl.initWindow(state.width, state.width, "yea");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(state.loop.framerate.current);
    state.update();
    var update_thread = try std.Thread.spawn(.{}, runUpdateLoop, .{&state});
    try runRenderLoop(&state);
    update_thread.detach();
}
fn runRenderLoop(state: *GameState) !void {
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        state.draw();
    }
}

fn runUpdateLoop(state: *GameState) void {
    while (!rl.windowShouldClose()) {
        state.update();
        state.sleepToNext();
    }
}
