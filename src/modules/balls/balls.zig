const rl = @import("raylib");
const rg = @import("raygui");
const std = @import("std");
const BallState = @import("./entities/ball.zig");
const LoopState = @import("../../loop.zig");
const meta = std.meta;

arena: std.heap.ArenaAllocator,
loop: LoopState,
width: i32 = 800,
height: i32 = 450,
backgroup_color: rl.Color = .white,
friction: f32 = 0.001,
balls: std.ArrayList(BallState),
balls_boundry: rl.Vector4 = .init(0, 0, 800, 450),

pub inline fn sleepToNext(self: *@This()) void {
    self.loop.sleepToNext();
}

pub fn swapBackgroud(self: *@This()) void {
    const eqls = meta.eql(self.backgroup_color, .white);
    self.backgroup_color = if (eqls) .black else .white;
}
pub fn createBall(s: *@This(), rand: *const std.Random) BallState {
    var ball: BallState = .init();
    ball.position = .init(
        (s.balls_boundry.x + s.balls_boundry.z) / 2,
        (s.balls_boundry.y + s.balls_boundry.w) / 2,
    );
    ball.force = rl.Vector2.one().scale(100).rotate(rand.float(f32) * 360);
    ball.mass = (rand.float(f32) * 600) + 600;
    ball.width = ball.mass / 200;
    return ball;
}

pub fn appendBalls(s: *@This(), count: usize) !void {
    const alloc = s.arena.allocator();
    var prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();
    for (0..count) |_| {
        try s.balls.append(alloc, s.createBall(&rand));
    }
}
pub fn resetBalls(s: *@This()) !void {
    var prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();

    for (s.balls.items) |*b| {
        b.* = s.createBall(&rand);
    }
}

pub fn init(allocactor: std.mem.Allocator, balls: usize) !@This() {
    return .{
        .arena = std.heap.ArenaAllocator.init(allocactor),
        .balls = try std.ArrayList(BallState).initCapacity(allocactor, @max(64, balls)),
        .loop = .init(),
    };
}
pub fn deinit(s: *@This()) void {
    s.arena.deinit();
}
pub fn update(s: *@This()) void {
    s.loop.update();
    s.width = rl.getScreenWidth();
    s.height = rl.getScreenHeight();
    s.balls_boundry = .init(20, 64, @floatFromInt(s.width - 20), @floatFromInt(s.height - 20));
    var config: BallState.Config = .{
        .allow_interaction = true,
        .boundry = &s.balls_boundry,
        .loopstate = &s.loop,
    };
    for (s.balls.items) |*ball| {
        ball.border_color = .gray;
        ball.update(&config);
        if (config.allow_interaction) config.allow_interaction = !ball.is_hold;
        // inner: for (s.balls.items[(i + 1)..]) |*other|
        //     if (ball.checkColision(other) != null) {
        //         ball.border_color = .blue;
        //         other.border_color = .blue;
        //         break :inner;
        //     };
    }
}
pub fn draw(s: *@This()) void {
    rl.clearBackground(s.backgroup_color);
    const txt = rl.textFormat("fps = %d tps = %f", .{ rl.getFPS(), 1 / s.loop.delta });
    rl.setWindowTitle(txt);

    if (rg.button(.init(24, 24, 120, 24), "btn")) s.swapBackgroud();
    if (rg.button(.init(160, 24, 120, 24), "reset")) s.resetBalls() catch {};

    const boundry: rl.Rectangle = .init(
        s.balls_boundry.x,
        s.balls_boundry.y,
        s.balls_boundry.z - s.balls_boundry.x,
        s.balls_boundry.w - s.balls_boundry.y,
    );

    rl.drawRectangleLinesEx(boundry, 2, rl.Color.gray);

    for (s.balls.items) |*ball| {
        ball.draw();
    }
}
