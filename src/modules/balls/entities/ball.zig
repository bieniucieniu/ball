const rl = @import("raylib");
const std = @import("std");
const Loop = @import("../../../loop.zig");
const ray = @import("../lib/raycast.zig");

state: State = .{},
color: rl.Color = .white,
border_color: rl.Color = .gray,
border_width: f32 = 2,
is_hold: bool = false,

pub const Config = struct {
    allow_interaction: bool,
    boundry: *rl.Vector4,
    loopstate: *Loop,
    friction: f32 = 0.01,
};

pub const State = struct {
    position: rl.Vector2 = .init(0, 0),
    force: rl.Vector2 = .init(0, 0),
    target_position: ?rl.Vector2 = null,
    width: f32 = 12,
    mass: f32 = 30,
    inline fn getMouseX(mouse: rl.Vector2, boundry: rl.Vector4) f32 {
        return if (mouse.x <= boundry.x)
            boundry.x
        else if (mouse.x >= boundry.z)
            boundry.z
        else
            mouse.x;
    }
    inline fn getMouseY(mouse: rl.Vector2, boundry: rl.Vector4) f32 {
        return if (mouse.y <= boundry.y)
            boundry.y
        else if (mouse.y >= boundry.w)
            boundry.w
        else
            mouse.y;
    }

    inline fn boundryLeft(s: *@This(), target: rl.Vector2, c: *const Config) bool {
        return target.x - s.width <= c.boundry.x;
    }
    inline fn boundryRight(s: *@This(), target: rl.Vector2, c: *const Config) bool {
        return target.x + s.width >= c.boundry.z;
    }

    inline fn boundryTop(s: *@This(), target: rl.Vector2, c: *const Config) bool {
        return target.y - s.width <= c.boundry.y;
    }
    inline fn boundryBottom(s: *@This(), target: rl.Vector2, c: *const Config) bool {
        return target.y + s.width >= c.boundry.w;
    }

    const BoundriesCrossed = packed struct(u4) {
        left: bool,
        right: bool,
        top: bool,
        bottom: bool,
        inline fn horizontal(self: @This()) bool {
            //@as(u4, self.*) & 0x1100;
            return self.left or self.right;
        }
        inline fn vertical(self: @This()) bool {
            //@as(u4, self.*) & 0x0011;
            return self.top or self.bottom;
        }
    };
    fn boundriesCrossed(s: *@This(), target: rl.Vector2, c: *const Config) BoundriesCrossed {
        return .{
            .left = s.boundryLeft(target, c),
            .right = s.boundryRight(target, c),
            .top = s.boundryTop(target, c),
            .bottom = s.boundryBottom(target, c),
        };
    }

    fn applyFriction(s: *@This(), c: *const Config) void {
        const base = (1 - c.friction * s.getScaler(c));
        s.force = s.force.scale(std.math.pow(f32, base, 2));
    }

    fn getMouse(mouse: rl.Vector2, boundry: rl.Vector4) rl.Vector2 {
        return rl.Vector2.init(
            getMouseX(mouse, boundry),
            getMouseY(mouse, boundry),
        );
    }

    pub fn addForce(s: *@This(), f: rl.Vector2, c: *const Config) void {
        s.force = s.force.add(f.scale(s.getScaler(c)));
    }
    inline fn getScaler(s: *@This(), c: *const Config) f32 {
        const per_s =
            if (c.loopstate.delta != 0)
                c.loopstate.delta * (1_000 / s.mass)
            else
                (1_000 / s.mass) / @as(f32, @floatFromInt(c.loopstate.tickrate.current));
        return per_s;
    }
    fn applyMouseAction(s: *@This(), c: *const Config, is_hold: bool) ?bool {
        const mouse = getMouse(rl.getMousePosition(), c.boundry.*);
        const mouse_down = rl.isMouseButtonDown(.left);
        if (mouse_down and c.allow_interaction) {
            if (mouse.distance(s.position) < s.width or is_hold) {
                s.force = mouse.subtract(s.position);
                return true;
            }
        } else return false;
        return null;
    }
    fn applyBoundryColisions(s: *@This(), target: *rl.Vector2, c: *const Config) void {
        const crossed = s.boundriesCrossed(target.*, c);
        if ((crossed.left and s.force.x < 0) or (crossed.right and s.force.x > 0)) s.force.x = -s.force.x;
        if ((crossed.top and s.force.y < 0) or (crossed.bottom and s.force.y > 0)) s.force.y = -s.force.y;

        if (crossed.left) target.x = c.boundry.x + s.width;
        if (crossed.right) target.x = c.boundry.z - s.width;
        if (crossed.top) target.y = c.boundry.y + s.width;
        if (crossed.bottom) target.y = c.boundry.w - s.width;

        //std.debug.print("{}\n{}\n{}\n{}\n\n", .{ crossed, target.*, s.boundry, s.loopstate });
    }

    fn applyColision(s: *@This(), other: *@This()) void {
        s.position.subtract(other.*);
    }
    pub fn checkIntersection(s: *@This(), other: *@This()) ?rl.Vector2 {
        return if (s.position.distanceSqr(other.position) <= std.math.pow(f32, s.width + other.width, 2))
            rl.Vector2.init(
                (s.position.x + other.position.x) / 2,
                (s.position.y + other.position.y) / 2,
            )
        else
            null;
    }

    pub fn checkRayColision(s: *@This(), o: *@This(), c: *Config) ?rl.Vector2 {
        const transform_vec = s.force.rotate(DEG_PER).normalize().scale(s.width);
        const next_s = s.getNextPosition(c).*;
        const next_o = o.getNextPosition(c).*;
        const colision_point =
            ray.raysIntersection(
                s.position.add(transform_vec),
                next_s.add(transform_vec),
                o.position.add(transform_vec),
                next_o.add(transform_vec),
            ) orelse
            ray.raysIntersection(
                s.position.add(transform_vec.negate()),
                next_s.add(transform_vec.negate()),
                o.position.add(transform_vec.negate()),
                next_o.add(transform_vec.negate()),
            );
        return colision_point;
    }

    pub fn checkColision(s: *@This(), other: *@This(), c: *Config) ?rl.Vector2 {
        return s.checkIntersection(other) orelse s.checkRayColision(other, c);
    }

    pub fn getRepultionForce(s: *@This(), other: *@This()) rl.Vector2 {
        var vec = s.position.subtract(other.position);
        const d = vec.lengthSqr() * 400;
        if (d == 0) return rl.Vector2.zero();
        const f = ((s.mass * other.mass) / d);
        vec = vec.normalize();

        return vec.scale(f);
    }
    pub fn getNextPosition(s: *@This(), c: *const Config) *rl.Vector2 {
        if (s.target_position) |*p| return p;
        const scaler = s.getScaler(c);
        const vec = s.force.scale(scaler);
        s.target_position = s.position.add(vec);
        if (s.target_position) |*p| return p else unreachable;
    }
};
pub fn update(s: *@This(), c: *const Config) void {
    defer s.state.target_position = null;
    if (s.state.applyMouseAction(c, s.is_hold)) |is_hold| {
        s.is_hold = is_hold;
    }
    s.state.applyFriction(c);
    const target = s.state.getNextPosition(c);
    s.state.applyBoundryColisions(target, c);
    s.state.position = target.*;
}

pub fn init() @This() {
    return .{};
}
const DEG_PER: f32 = std.math.pi / 2.0;
pub fn draw(s: *@This()) void {
    const force = s.state.force;
    const transform_vec = force.normalize().scale(s.state.width);
    const target_vec = s.state.position.add(force.scale(0.1));
    rl.drawLineEx(
        s.state.position.add(transform_vec),
        target_vec.add(transform_vec),
        1,
        s.border_color.alpha(0.1),
    );
    rl.drawRing(
        s.state.position,
        s.state.width,
        s.state.width + s.border_width,
        0,
        360,
        12,
        s.border_color,
    );
}
