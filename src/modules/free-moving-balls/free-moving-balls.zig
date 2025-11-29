const rl = @import("raylib");
const std = @import("std");
const Shared = @import("../shared.zig");
pub const Ball = @import("./entities/ball.zig");
const Loop = Shared.Loop;
const meta = std.meta;

width: i32 = 800,
height: i32 = 450,
friction: f32 = 0.01,
balls: std.ArrayList(Ball),
balls_mal: std.MultiArrayList(Ball) = .{},
balls_boundry: rl.Vector4 = .init(0, 0, 800, 450),
balls_sap: Shared.Sap.TagedSap(*Ball),
restitution: f32 = 1,
pub fn createRandomBall(s: *@This(), rand: *const std.Random) Ball {
    var ball: Ball = .init(&s.balls_boundry);
    ball.state.position = .init(
        (s.balls_boundry.x + s.balls_boundry.z) / 2,
        (s.balls_boundry.y + s.balls_boundry.w) / 2,
    );
    ball.state.force = rl.Vector2.one().scale(64).rotate(rand.float(f32) * 360);
    ball.state.mass = (rand.float(f32) * 600) + 600;
    ball.state.width = ball.state.mass / 100;
    return ball;
}
pub fn appendBalls(s: *@This(), alloc: std.mem.Allocator, count: usize) !void {
    var prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();
    for (try s.balls.addManyAsSlice(alloc, count)) |*b| b.* = s.createRandomBall(&rand);
}
pub fn reset(s: *@This()) !void {
    var prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();

    for (s.balls.items) |*b| {
        b.* = s.createRandomBall(&rand);
    }
}
pub fn init(allocactor: std.mem.Allocator, balls: usize) !@This() {
    return .{
        .balls = try std.ArrayList(Ball).initCapacity(allocactor, @max(64, balls)),
        .balls_sap = try .init(allocactor, balls),
    };
}
pub fn setupState(s: *@This()) !void {
    return s.update(0);
}
pub fn deinit(s: *@This(), alloc: std.mem.Allocator) void {
    s.balls_sap.deinit(alloc);
    s.balls_mal.deinit(alloc);
    s.balls.deinit(alloc);
}
pub fn updateBoundry(s: *@This(), width: i32, height: i32) void {
    _ = s;
    _ = rl.Vector4.init(20, 64, @floatFromInt(width - 20), @floatFromInt(height - 20));
}
pub fn update(s: *@This(), alloc: std.mem.Allocator, delta: f32) void {
    for (s.balls_sap.setQuadsAsSlice(alloc, s.balls.items.len) catch return, 0..) |*q, i| {
        const b = &s.balls.items[i];
        // b.border_color = .gray;
        b.update(delta);

        const x = b.state.position.x;
        const w = b.state.width;
        q.* = .init(x - w, x + w, b);
    }
    s.balls_sap.sortQuadsInplace();

    for (s.balls_sap.getPairs(alloc) catch return) |pair| {
        const a, const b = pair;
        if (a.state.checkColision(&b.state, delta)) |_| {
            a.state.applyCollision(
                &b.state,
                s.restitution,
            );
        }
    }
}
pub inline fn draw(s: *@This(), bounds: rl.Rectangle) void {
    const scale = blk: {
        const scale_w = bounds.width / @as(f32, @floatFromInt(s.width));
        const scale_h = bounds.height / @as(f32, @floatFromInt(s.height));

        break :blk if (scale_w < scale_h) scale_w else scale_h;
    };
    const offset = rl.Vector2.init(bounds.x, bounds.y);

    rl.drawRectangleLinesEx(.init(
        offset.x,
        offset.y,
        @as(f32, @floatFromInt(s.width)) * scale,
        @as(f32, @floatFromInt(s.height)) * scale,
    ), 2, .gray);

    for (s.balls.items) |*ball| {
        ball.draw(offset, scale);
    }
}
