const rl = @import("raylib");
const std = @import("std");
const loop = @import("../../../loop.zig");

pub const BallState = struct {
    loopstate: *loop.LoopState,

    position: rl.Vector2 = .init(0, 0),
    force: rl.Vector2 = .init(0, 0),
    target_position: ?rl.Vector2 = null,

    width: f32 = 12,
    friction: f32 = 0.001,
    mass: f32 = 30,

    boundry: *rl.Vector4,
    color: rl.Color = .white,
    border_color: rl.Color = .gray,
    border_width: f32 = 2,
    is_hold: bool = false,

    inline fn getMouseX(s: *@This(), mouse: rl.Vector2) f32 {
        return if (mouse.x <= s.boundry.x)
            s.boundry.x
        else if (mouse.x >= s.boundry.z)
            s.boundry.z
        else
            mouse.x;
    }
    inline fn getMouseY(s: *@This(), mouse: rl.Vector2) f32 {
        return if (mouse.y <= s.boundry.y)
            s.boundry.y
        else if (mouse.y >= s.boundry.w)
            s.boundry.w
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

    fn applyFriction(s: *@This()) void {
        s.force = s.force.scale((1 - s.friction * s.getScaler()));
    }

    fn getMouse(s: *@This(), mouse: rl.Vector2) rl.Vector2 {
        return rl.Vector2.init(s.getMouseX(mouse), s.getMouseY(mouse));
    }
    inline fn getScaler(s: *@This()) f32 {
        const per_s =
            if (s.loopstate.delta != 0)
                s.loopstate.delta * (1_000 / s.mass)
            else
                (1_000 / s.mass) / @as(f32, @floatFromInt(s.loopstate.tickrate.current));
        return per_s;
    }
    fn updateForceVector(s: *@This(), allow_interaction: bool) void {
        const mouse = s.getMouse(rl.getMousePosition());
        const mouse_down = rl.isMouseButtonDown(.left);
        if (mouse_down and allow_interaction) {
            if (mouse.distance(s.position) < s.width or s.is_hold) {
                s.is_hold = true;
                s.force = mouse.subtract(s.position);
            }
        } else s.is_hold = false;
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

    pub fn checkRayColision(s: *@This(), other: *@This()) ?rl.Vector2 {
        const rays = raysIntersection(s.position, s.getNextPosition().*, other.position, other.getNextPosition().*);
        return rays;
    }
    pub fn checkColision(s: *@This(), other: *@This()) ?rl.Vector2 {
        return checkIntersection(s, other) orelse checkRayColision(s, other);
    }
    pub fn getNextPosition(s: *@This()) *rl.Vector2 {
        if (s.target_position) |*p| return p;
        const scaler = s.getScaler();
        const vec = s.force.scale(scaler);
        s.target_position = s.position.add(vec);
        if (s.target_position) |*p| return p else unreachable;
    }
    pub fn update(s: *@This(), allow_interaction: bool) void {
        defer s.target_position = null;
        s.updateForceVector(allow_interaction);
        s.applyFriction();
        const target = s.getNextPosition();
        s.applyBoundryColisions(target);
        s.position = target.*;
    }
    pub fn init(loopstate: *loop.LoopState, boundry: *rl.Vector4) @This() {
        return .{ .loopstate = loopstate, .boundry = boundry };
    }
    pub fn draw(s: *@This()) void {
        const force = s.force;
        rl.drawLineEx(
            s.position,
            s.position.add(force),
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
};

fn raysIntersection(as: rl.Vector2, ad: rl.Vector2, bs: rl.Vector2, bd: rl.Vector2) ?rl.Vector2 {
    if (as.equals(bs) != 0) return as;
    const dx = bs.x - as.x;
    const dy = bs.y - as.y;
    const det = bd.x * ad.y - bd.y * ad.x;
    if (det != 0) { // near parallel line will yield noisy results
        const u = (dy * bd.x - dx * bd.y) / det;
        const v = (dy * ad.x - dx * ad.y) / det;
        if (u >= 0 and u <= 1 and v >= 0 and v <= 1) {
            return as.add(ad).scale(u);
        }
    }
    return null;
}
