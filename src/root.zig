const rl = @import("raylib");
const rg = @import("raygui");
const std = @import("std");

const shared = @import("./modules/shared.zig");
const Loop = shared.Loop;
const App = @import("./modules/app/app.zig");
const meta = std.meta;
const bufPrint = std.fmt.bufPrint;
const Options = shared.Options;

const TARGET_FPS = 240;

pub fn run(allocator: std.mem.Allocator) !void {
    var loop: Loop = .init(TARGET_FPS);
    var app: App = .{};

    const options = try Options.create(allocator, .{});
    if (options.help and Options.CLI) {
        try Options.printHelp(.stdout());
        std.process.exit(0);
        return;
    }

    try app.configurate(allocator, options);
    defer app.deinit(allocator);

    rl.setConfigFlags(.{ .window_resizable = true });
    rl.initWindow(app.width, app.width, "balls be rolling");
    defer rl.closeWindow();

    rl.setTargetFPS(loop.framerate.current);
    app.update(allocator, loop.delta);
    var update_thread = try std.Thread.spawn(.{}, runUpdateLoop, .{ &loop, &app, allocator });
    // defer update_thread.detach();
    try runRenderLoop(&loop, &app, allocator);
    update_thread.join();
}

pub fn runSingleThreaded(allocator: std.mem.Allocator) !void {
    var app: App = .{};
    try app.configurate(allocator, try Options.create(allocator, .{}));
    defer app.deinit(allocator);

    rl.setConfigFlags(.{ .window_resizable = true });
    rl.initWindow(app.width, app.width, "balls be rolling");
    defer rl.closeWindow();

    rl.setTargetFPS(TARGET_FPS);
    app.update(allocator, rl.getFrameTime());

    try runLoop(&app, allocator);
}

fn runRenderLoop(loop: *Loop, app: *App, alloc: std.mem.Allocator) !void {
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.setWindowTitle(rl.textFormat("fps = %d tps = %f", .{ rl.getFPS(), 1 / loop.delta }));
        // alloc should be removed from draw
        app.draw(alloc);
    }
}

fn runUpdateLoop(loop: *Loop, app: *App, alloc: std.mem.Allocator) !void {
    while (!rl.windowShouldClose()) {
        loop.update();
        defer loop.sleepToNext();
        app.update(alloc, loop.delta);
    }
}

fn runLoop(app: *App, alloc: std.mem.Allocator) !void {
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.setWindowTitle(rl.textFormat("fps = %d", .{rl.getFPS()}));
        app.update(alloc, rl.getFrameTime());
        app.draw(alloc);
    }
}
