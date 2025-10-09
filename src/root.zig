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
    //
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const allocator = gpa.allocator();
    var state: GameState = try .init(allocator, 2137);

    rl.setConfigFlags(.{
        .window_resizable = true,
    });
    rl.initWindow(state.width, state.width, "raylib-zig [core] example - basic window");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(state.loop.tickrate.current);
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
    arena: std.heap.ArenaAllocator,
    loop: LoopState,
    width: i32 = 800,
    height: i32 = 450,
    backgroup_color: rl.Color = .white,
    balls: std.ArrayList(BallState),
    fn updateRate(self: *@This()) void {
        const s = self.loop.tickrate.getScaler();
        for (self.balls.items) |*ball| {
            ball.scale = s;
        }
    }
    inline fn sleepToNext(self: *@This()) void {
        self.loop.sleepToNext();
    }

    fn swapBackgroud(self: *@This()) void {
        const eqls = meta.eql(self.backgroup_color, .white);
        self.backgroup_color = if (eqls) .black else .white;
    }

    fn init(allocactor: std.mem.Allocator, balls: usize) !@This() {
        var state: @This() = .{ .arena = std.heap.ArenaAllocator.init(allocactor), .balls = try std.ArrayList(BallState).initCapacity(allocactor, @max(64, balls)), .loop = .init() };
        const alloc = state.arena.allocator();
        var prng = std.Random.DefaultPrng.init(blk: {
            var seed: u64 = undefined;
            try std.posix.getrandom(std.mem.asBytes(&seed));
            break :blk seed;
        });
        const rand = prng.random();
        for (0..balls) |i| {
            var ball: BallState = .init();
            _ = i;
            ball.position = .init(
                @as(f32, @floatFromInt(state.width)) / 2 + @as(f32, @floatFromInt(0 * 24)),
                @max(@as(f32, @floatFromInt(state.height)) / 2, 256 + 24) + @as(f32, @floatFromInt(0 * 24)),
            );
            ball.force = rl.Vector2.one().scale(100).rotate(rand.float(f32) * 360);
            try state.balls.append(alloc, ball);
        }
        state.updateRate();
        return state;
    }

    fn deinit(s: *@This()) void {
        s.arena.deinit();
    }
    fn update(s: *@This()) void {
        s.loop.update();
        s.width = rl.getScreenWidth();
        s.height = rl.getScreenHeight();
        const boundry: rl.Vector4 = .init(20, 256, @floatFromInt(s.width - 20), @floatFromInt(s.height - 20));
        var allow_interaction = true;
        for (s.balls.items) |*ball| {
            ball.boundry = boundry;
            ball.update(allow_interaction);
            if (allow_interaction)
                allow_interaction = !ball.is_hold;
        }
    }
    fn draw(s: *@This()) void {
        if (rg.button(.init(24, 24, 120, 24), "btn")) s.swapBackgroud();
        // var framerate: f32 = @floatFromInt(s.loop.framerate.hight);
        // var tickrate: f32 = @floatFromInt(s.loop.tickrate.hight);
        // const fr_low = rl.textFormat("%d", .{s.loop.framerate.low});
        // if (rg.slider(.init(24, 56, @floatFromInt(s.width - 24 * 2), 24), fr_low, "240", &framerate, @floatFromInt(s.loop.framerate.low), 240) != 0)
        //     s.loop.framerate.hight = @intFromFloat(framerate);
        //
        // const tr_low = rl.textFormat("%d", .{s.loop.tickrate.low});
        // if (rg.sliderBar(.init(24, 80, @floatFromInt(s.width - 24 * 2), 24), tr_low, "240", &tickrate, @floatFromInt(s.loop.tickrate.low), 240) != 0)
        //     s.loop.tickrate.hight = @intFromFloat(tickrate);
        //
        // const fr = rl.textFormat("framerrate = %f | %d", .{ framerate, s.loop.framerate.current });
        // rl.drawText(fr, 24, 120, 32, .gray);
        //const tr = rl.textFormat("tickrate   = %f | %d", .{ tickrate, s.loop.tickrate.current });

        rl.drawText(rl.textFormat("%d", .{s.balls.items.len}), 24, 152, 32, .gray);

        rl.clearBackground(s.backgroup_color);
        const txt = rl.textFormat("fps = %d", .{rl.getFPS()});
        rl.setWindowTitle(txt);
        _ = rg.windowBox(.init(24, 24, 120, 60), "asdljkashldkjas");

        for (s.balls.items) |*ball| {
            ball.draw();
        }
    }
};
