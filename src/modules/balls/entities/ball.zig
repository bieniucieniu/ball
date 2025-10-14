const rl = @import("raylib");
const std = @import("std");
const Loop = @import("../../../loop.zig");
const ray = @import("../lib/raycast.zig");

pub const Config = struct {
    allow_interaction: bool,
    boundry: *rl.Vector4,
    loopstate: *Loop,
    friction: f32 = 0.01,
};

position: rl.Vector2 = .init(0, 0),
force: rl.Vector2 = .init(0, 0),
target_position: ?rl.Vector2 = null,
width: f32 = 12,
mass: f32 = 30,
color: rl.Color = .white,
border_color: rl.Color = .gray,
border_width: f32 = 2,
is_hold: bool = false,

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
    s.force = s.force.scale((1 - c.friction * s.getScaler(c)));
}

fn getMouse(mouse: rl.Vector2, boundry: rl.Vector4) rl.Vector2 {
    return rl.Vector2.init(
        getMouseX(mouse, boundry),
        getMouseY(mouse, boundry),
    );
}
inline fn getScaler(s: *@This(), c: *const Config) f32 {
    const per_s =
        if (c.loopstate.delta != 0)
            c.loopstate.delta * (1_000 / s.mass)
        else
            (1_000 / s.mass) / @as(f32, @floatFromInt(c.loopstate.tickrate.current));
    return per_s;
}
fn updateForceVector(s: *@This(), c: *const Config) void {
    const mouse = getMouse(rl.getMousePosition(), c.boundry.*);
    const mouse_down = rl.isMouseButtonDown(.left);
    if (mouse_down and c.allow_interaction) {
        if (mouse.distance(s.position) < s.width or s.is_hold) {
            s.is_hold = true;
            s.force = mouse.subtract(s.position);
        }
    } else s.is_hold = false;
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

pub fn checkRayColision(s: *@This(), other: *@This()) ?rl.Vector2 {
    const transform_vec = s.force.rotate(DEG_PER).normalize().scale(s.width);
    const colision_point =
        ray.raysIntersection(
            s.position.add(transform_vec),
            s.getNextPosition().*.add(transform_vec),
            other.position.add(transform_vec),
            other.getNextPosition().*.add(transform_vec),
        ) orelse
        ray.raysIntersection(
            s.position.add(transform_vec.negate()),
            s.getNextPosition().*.add(transform_vec.negate()),
            other.position.add(transform_vec.negate()),
            other.getNextPosition().*.add(transform_vec.negate()),
        );
    return colision_point;
}

pub fn checkColision(s: *@This(), other: *@This()) ?rl.Vector2 {
    return s.checkIntersection(other) orelse s.checkRayColision(other);
}

pub fn getRepultionForce(s: *@This(), other: *@This()) rl.Vector2 {
    var vec = other.position.subtract(s.position);
    const f = (s.mass * other.mass) / vec.lengthSqr();
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
pub fn update(s: *@This(), c: *const Config) void {
    defer s.target_position = null;
    s.updateForceVector(c);
    s.applyFriction(c);
    const target = s.getNextPosition(c);
    s.applyBoundryColisions(target, c);
    s.position = target.*;
}

pub fn init() @This() {
    return .{};
}
const DEG_PER: f32 = std.math.pi / 2.0;
pub fn draw(s: *@This()) void {
    const force = s.force;
    const transform_vec = force.rotate(DEG_PER).normalize().scale(s.width);
    const target_vec = s.position.add(force);
    rl.drawLineEx(
        s.position.add(transform_vec),
        target_vec.add(transform_vec),
        1,
        s.border_color,
    );
    rl.drawLineEx(
        s.position.add(transform_vec.negate()),
        target_vec.add(transform_vec.negate()),
        1,
        s.border_color,
    );
    rl.drawRing(
        s.position,
        s.width,
        s.width + s.border_width,
        0,
        360,
        12,
        s.border_color,
    );
}
