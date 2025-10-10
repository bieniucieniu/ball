const rl = @import("raylib");
const rg = @import("raygui");
const std = @import("std");
const BallState = @import("./entities/ball.zig").BallState;
const LoopState = @import("./loop.zig").LoopState;
const meta = std.meta;

pub const GameState = struct {
    arena: std.heap.ArenaAllocator,
    loop: LoopState,
    width: i32 = 800,
    height: i32 = 450,
    backgroup_color: rl.Color = .white,
    balls: std.ArrayList(BallState),
    balls_boundry: rl.Vector4 = .init(0, 0, 800, 450),

    pub inline fn sleepToNext(self: *@This()) void {
        self.loop.sleepToNext();
    }

    pub fn swapBackgroud(self: *@This()) void {
        const eqls = meta.eql(self.backgroup_color, .white);
        self.backgroup_color = if (eqls) .black else .white;
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
            var ball: BallState = .init(
                &s.loop,
                &s.balls_boundry,
            );
            ball.position = .init(
                (s.balls_boundry.x + s.balls_boundry.z) / 2,
                (s.balls_boundry.y + s.balls_boundry.w) / 2,
            );
            ball.force = rl.Vector2.one().scale(100).rotate(rand.float(f32) * 360);
            try s.balls.append(alloc, ball);
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
        var allow_interaction = true;
        for (s.balls.items) |*ball| {
            ball.boundry = &s.balls_boundry;
            ball.update(allow_interaction);
            if (allow_interaction)
                allow_interaction = !ball.is_hold;
        }
    }
    pub fn draw(s: *@This()) void {
        rl.clearBackground(s.backgroup_color);
        const txt = rl.textFormat("fps = %d tps = %f", .{ rl.getFPS(), 1 / s.loop.delta });
        rl.setWindowTitle(txt);
        const posX: i32 = @intFromFloat(s.balls_boundry.x);
        const posY: i32 = @intFromFloat(s.balls_boundry.y);
        const width = @as(i32, @intFromFloat(s.balls_boundry.z)) - posX;
        const height = @as(i32, @intFromFloat(s.balls_boundry.w)) - posY;

        const border = 2;
        if (rg.button(.init(24, 24, 120, 24), "btn")) s.swapBackgroud();

        rl.drawRectangle(
            posX - border,
            posY - border,
            width + border * 2,
            height + border * 2,
            rl.Color.gray,
        );
        rl.drawRectangle(
            posX,
            posY,
            width,
            height,
            rl.Color.white,
        );
        rl.drawRectangle(
            posX,
            posY,
            width,
            height,
            s.backgroup_color,
        );

        for (s.balls.items) |*ball| {
            ball.draw();
        }
    }
};
