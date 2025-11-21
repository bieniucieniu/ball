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

pub fn run(allocator: std.mem.Allocator, pool: *std.Thread.Pool) !void {
    var app: App = .init(allocator);
    const options = try Options.create(allocator, .{});
    if (options.help and Options.CLI) {
        try Options.printHelp(.stdout());
        std.process.exit(0);
        return;
    }

    try app.configurate(options);
    defer app.deinit();

    rl.setConfigFlags(.{ .window_resizable = true });
    rl.initWindow(app.width, app.width, "balls be rolling");
    defer rl.closeWindow();

    if (options.single_threaded) {
        rl.setTargetFPS(TARGET_FPS);
        return runLoop(&app);
    }

    var loop: Loop = .init(TARGET_FPS);
    var wg: std.Thread.WaitGroup = .{};
    rl.setTargetFPS(loop.framerate.current);
    app.update(loop.delta);

    pool.spawnWg(&wg, runUpdateLoop, .{ &loop, &app });
    pool.spawnWg(&wg, runRenderLoop, .{ &loop, &app });
    pool.waitAndWork(&wg);
}

fn runRenderLoop(loop: *Loop, app: *App) void {
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.setWindowTitle(rl.textFormat("fps = %d tps = %f", .{ rl.getFPS(), 1 / loop.delta }));
        // alloc should be removed from draw
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

fn runLoop(app: *App) void {
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.setWindowTitle(rl.textFormat("fps = %d", .{rl.getFPS()}));
        app.update(rl.getFrameTime());
        app.draw();
    }
}
