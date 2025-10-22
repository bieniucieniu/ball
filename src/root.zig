const rl = @import("raylib");
const rg = @import("raygui");
const std = @import("std");

const shared = @import("./modules/shared.zig");
const Loop = shared.Loop;
const App = @import("./modules/app/app.zig");
const meta = std.meta;
const bufPrint = std.fmt.bufPrint;

pub fn run(allocator: std.mem.Allocator) !void {
    var loop: Loop = .init(240);
    var state: App = try .init(allocator);
    defer state.deinit();

    rl.setConfigFlags(.{ .window_resizable = true });
    rl.initWindow(state.width, state.width, "yea");
    defer rl.closeWindow();

    rl.setTargetFPS(loop.framerate.current);
    state.update(loop.delta);
    var update_thread = try std.Thread.spawn(.{}, runUpdateLoop, .{ &loop, &state });
    // defer update_thread.detach();
    try runRenderLoop(&loop, &state);
    update_thread.join();
}

fn runRenderLoop(loop: *Loop, app: *App) !void {
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.setWindowTitle(rl.textFormat("fps = %d tps = %f", .{ rl.getFPS(), 1 / loop.delta }));
        app.draw();
    }
}

fn runUpdateLoop(loop: *Loop, app: *App) void {
    while (!rl.windowShouldClose()) {
        loop.update();
        defer loop.sleepToNext();
        app.update(loop.delta);
    }
}
