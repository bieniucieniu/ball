const rl = @import("raylib");
const rg = @import("raygui");
const std = @import("std");
const BallState = @import("./entities/ball.zig").BallState;
const LoopState = @import("./loop.zig").LoopState;
const meta = std.meta;
const bufPrint = std.fmt.bufPrint;

pub fn run() !void {
    // Initialization
    //--------------------------------------------------------------------------------------
    //
    var state: GameState = .init();

    rl.setConfigFlags(.{
        .window_resizable = true,
    });
    rl.initWindow(state.width, state.width, "raylib-zig [core] example - basic window");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(state.tickrate);
    //   var timer = try std.time.Timer.start();
    var update_thread = try std.Thread.spawn(.{}, runUpdateLoop, .{
        &state,
    });
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
        state.loop.sleepToNext();
    }
}

const GameState = struct {
    loop: LoopState,
    tickrate: i32 = 60,
    unfocused_tickrate: i32 = 20,
    width: i32 = 800,
    height: i32 = 450,
    backgroup_color: rl.Color = .white,
    ball: BallState,
    fn updateRate(self: *@This()) void {
        _ = self;
    }
    inline fn sleepToNext(self: *@This()) void {
        self.loop.sleepToNext();
    }

    fn update(self: *@This()) void {
        self.loop.update();
        self.width = rl.getScreenWidth();
        self.height = rl.getScreenHeight();
        self.ball.updateBoundry(20, 20, @floatFromInt(self.width - 20), @floatFromInt(self.height - 20));
        self.ball.update();
    }
    fn swapBackgroud(self: *@This()) void {
        const eqls = meta.eql(self.backgroup_color, .white);
        self.backgroup_color = if (eqls) .black else .white;
    }

    fn init() @This() {
        return .{ .ball = .init(), .loop = .init() };
    }
    fn draw(s: *@This()) void {
        if (rg.button(.init(24, 24, 120, 24), "btn")) s.swapBackgroud();

        var framerate: f32 = @floatFromInt(s.loop.framerate.hight);
        var tickrate: f32 = @floatFromInt(s.loop.tickrate.hight);

        const fr_low = rl.textFormat("%d", .{s.loop.framerate.low});
        if (rg.slider(.init(24, 56, @floatFromInt(s.width - 24 * 2), 24), fr_low, "240", &framerate, @floatFromInt(s.loop.framerate.low), 240) != 0)
            s.loop.framerate.hight = @intFromFloat(framerate);

        const tr_low = rl.textFormat("%d", .{s.loop.tickrate.low});
        if (rg.sliderBar(.init(24, 80, @floatFromInt(s.width - 24 * 2), 24), tr_low, "240", &tickrate, @floatFromInt(s.loop.tickrate.low), 240) != 0)
            s.loop.tickrate.hight = @intFromFloat(tickrate);

        const fr = rl.textFormat("framerrate = %f | %d", .{ framerate, s.loop.framerate.current });
        rl.drawText(fr, 24, 120, 32, .gray);
        const tr = rl.textFormat("tickrate   = %f | %d", .{ tickrate, s.loop.tickrate.current });
        rl.drawText(tr, 24, 152, 32, .gray);

        rl.clearBackground(s.backgroup_color);
        const txt = rl.textFormat("fps = %d mouse = .{.x = %.0f, .y = %.0f} mouse.y = .{.x = %.0f, .y = %.0f}", .{ rl.getFPS(), s.ball.mouse.x, s.ball.mouse.y, s.ball.position.x, s.ball.position.y });
        rl.setWindowTitle(txt);

        s.ball.draw();
    }
};
