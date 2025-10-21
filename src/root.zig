const rl = @import("raylib");
const rg = @import("raygui");
const std = @import("std");
const LoopState = @import("./modules/shared/loop/loop.zig");
const AppState = @import("./modules/app/app.zig");
const meta = std.meta;
const bufPrint = std.fmt.bufPrint;

pub fn run() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const allocator = gpa.allocator();

    var loopState: LoopState = .init();
    var state: AppState = try .init(allocator);
    defer state.deinit();

    //try state.appendBalls(count);

    rl.setConfigFlags(.{ .window_resizable = true });
    rl.initWindow(state.width, state.width, "yea");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(loopState.framerate.current);
    state.update(loopState.delta);
    var update_thread = try std.Thread.spawn(.{}, runUpdateLoop, .{ &loopState, &state });
    defer update_thread.detach();
    try runRenderLoop(&loopState, &state);
}

fn runRenderLoop(loop: *LoopState, state: *AppState) !void {
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.setWindowTitle(rl.textFormat("fps = %d tps = %f", .{ rl.getFPS(), 1 / loop.delta }));
        state.draw();
    }
}

fn runUpdateLoop(loop: *LoopState, state: *AppState) void {
    while (!rl.windowShouldClose()) {
        loop.update();
        defer loop.sleepToNext();
        state.update(loop.delta);
    }
}
