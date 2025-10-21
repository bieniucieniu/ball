const rl = @import("raylib");
const std = @import("std");
const Shared = @import("../../shared.zig");
const Quad = @import("../../shared/sap/quad.zig");
const Loop = Shared.Loop;
const ray = Shared.Raycast;

state: State,
color: rl.Color = .white,
border_color: rl.Color = .gray,
border_width: f32 = 2,
is_hold: bool = false,

pub const State = struct {
    position: rl.Vector2 = .init(0, 0),
    force: rl.Vector2 = .init(0, 0),
    target_position: ?rl.Vector2 = null,
    width: f32 = 12,
    mass: f32 = 30,
    boundry: *rl.Vector4,
    pub fn init(boundry: *rl.Vector4) @This() {
        return .{ .boundry = boundry };
    }
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

    inline fn boundryLeft(s: *@This(), target: rl.Vector2) bool {
        return target.x - s.width <= s.boundry.x;
    }
    inline fn boundryRight(s: *@This(), target: rl.Vector2) bool {
        return target.x + s.width >= s.boundry.z;
    }

    inline fn boundryTop(s: *@This(), target: rl.Vector2) bool {
        return target.y - s.width <= s.boundry.y;
    }
    inline fn boundryBottom(s: *@This(), target: rl.Vector2) bool {
        return target.y + s.width >= s.boundry.w;
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
    fn boundriesCrossed(s: *@This(), target: rl.Vector2) BoundriesCrossed {
        return .{
            .left = s.boundryLeft(target),
            .right = s.boundryRight(target),
            .top = s.boundryTop(target),
            .bottom = s.boundryBottom(target),
        };
    }

    fn getMouse(mouse: rl.Vector2, boundry: rl.Vector4) rl.Vector2 {
        return rl.Vector2.init(
            getMouseX(mouse, boundry),
            getMouseY(mouse, boundry),
        );
    }

    inline fn getScaler(s: *@This(), delta: f32) f32 {
        const per_s = delta * (1_000 / s.mass);
        return per_s;
    }
    fn applyMouseAction(s: *@This(), is_hold: bool) ?bool {
        const mouse = getMouse(rl.getMousePosition(), s.boundry.*);
        const mouse_down = rl.isMouseButtonDown(.left);
        if (mouse_down) {
            if (mouse.distance(s.position) < s.width or is_hold) {
                s.force = mouse.subtract(s.position);
                return true;
            }
        } else return false;
        return null;
    }
    fn applyBoundryColisions(s: *@This(), target: *rl.Vector2) void {
        const crossed = s.boundriesCrossed(target.*);
        if ((crossed.left and s.force.x < 0) or (crossed.right and s.force.x > 0)) s.force.x = -s.force.x;
        if ((crossed.top and s.force.y < 0) or (crossed.bottom and s.force.y > 0)) s.force.y = -s.force.y;

        if (crossed.left) target.x = s.boundry.x + s.width;
        if (crossed.right) target.x = s.boundry.z - s.width;
        if (crossed.top) target.y = s.boundry.y + s.width;
        if (crossed.bottom) target.y = s.boundry.w - s.width;

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

    pub fn checkRayColision(s: *@This(), o: *@This(), delta: f32) ?rl.Vector2 {
        const transform_vec = s.force.rotate(DEG_PER).normalize().scale(s.width);
        const next_s = s.getNextPosition(delta).*;
        const next_o = o.getNextPosition(delta).*;
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

    pub fn checkColision(s: *@This(), other: *@This(), delta: f32) ?rl.Vector2 {
        _ = delta;
        return s.checkIntersection(other); // orelse s.checkRayColision(other, delta);
    }

    pub fn getRepultionForce(s: *@This(), other: *@This()) rl.Vector2 {
        var vec = s.position.subtract(other.position);
        const d = vec.lengthSqr() * 400;
        if (d == 0) return rl.Vector2.zero();
        const f = ((s.mass * other.mass) / d);
        vec = vec.normalize();

        return vec.scale(f);
    }
    pub fn getNextPosition(s: *@This(), delta: f32) *rl.Vector2 {
        if (s.target_position) |*p| return p;
        const scaler = s.getScaler(delta);
        const vec = s.force.scale(scaler);
        s.target_position = s.position.add(vec);
        if (s.target_position) |*p| return p else unreachable;
    }
};
pub fn update(s: *@This(), delta: f32) void {
    defer s.state.target_position = null;
    if (s.state.applyMouseAction(s.is_hold)) |is_hold| {
        s.is_hold = is_hold;
    }
    const target = s.state.getNextPosition(delta);
    s.state.applyBoundryColisions(target);
    s.state.position = target.*;
}

pub fn init(boundry: *rl.Vector4) @This() {
    return .{ .state = .init(boundry) };
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

pub inline fn quad(s: *@This(), o: Quad.Axis) Quad {
    const w = s.state.width;
    switch (o) {
        .x, .horizontal => {
            const x = s.state.position.x;
            return .{ .min = x - w, .max = x + w };
        },
        .y, .vertical => {
            const y = s.state.position.y;
            return .{ .min = y - w, .max = y + w };
        },
    }
}
