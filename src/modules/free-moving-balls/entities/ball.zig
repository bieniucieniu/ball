const rl = @import("raylib");
const std = @import("std");
const Shared = @import("../../shared.zig");
const Quad = @import("../../shared/sap/quad.zig");
const Loop = Shared.Loop;
const ray = Shared.Raycast;
const m = Shared.mouse;

state: State,
color: rl.Color = .white,
border_color: rl.Color = .gray,
border_width: f32 = 2,

pub const State = struct {
    position: rl.Vector2 = .init(0, 0),
    force: rl.Vector2 = .init(0, 0),
    width: f32 = 12,
    mass: f32 = 30,
    bounds: *rl.Rectangle,
    is_hold: bool = false,
    pub fn init(boundry: *rl.Rectangle) @This() {
        return .{ .bounds = boundry };
    }

    inline fn boundryLeft(s: *@This(), target: rl.Vector2) bool {
        return target.x - s.width <= s.bounds.x;
    }
    inline fn boundryRight(s: *@This(), target: rl.Vector2) bool {
        return target.x + s.width >= s.bounds.x + s.bounds.width;
    }

    inline fn boundryTop(s: *@This(), target: rl.Vector2) bool {
        return target.y - s.width <= s.bounds.y;
    }
    inline fn boundryBottom(s: *@This(), target: rl.Vector2) bool {
        return target.y + s.width >= s.bounds.y + s.bounds.height;
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

    inline fn getDeltaScaler(s: *@This(), delta: f32) f32 {
        const per_s = delta * (1_000 / s.mass);
        return per_s;
    }

    fn applyMouseAction(s: *@This(), offset: rl.Vector2, scale: f32) void {
        const bounds = rl.Rectangle.init(
            offset.x + s.bounds.x,
            offset.y + s.bounds.y,
            s.bounds.width * scale,
            s.bounds.height * scale,
        );
        const mouse = m.getMouse(bounds);
        const mouse_down = rl.isMouseButtonDown(.left);
        if (mouse_down) {
            const pos = s.position.scale(scale).add(offset);
            var d = s.width * scale;
            d = d * d;
            if ((mouse.distanceSqr(pos) < d) or s.is_hold) {
                s.force = mouse.subtract(pos);
                s.is_hold = true;
            }
        } else s.is_hold = false;
    }
    fn applyBoundryColisions(s: *@This(), target: *rl.Vector2) void {
        const crossed = s.boundriesCrossed(target.*);
        if ((crossed.left and s.force.x < 0) or (crossed.right and s.force.x > 0)) s.force.x = -s.force.x;
        if ((crossed.top and s.force.y < 0) or (crossed.bottom and s.force.y > 0)) s.force.y = -s.force.y;

        if (crossed.left) {
            target.x = s.bounds.x + s.width;
        } else if (crossed.right) {
            target.x = s.bounds.x + s.bounds.width - s.width;
        }
        if (crossed.top) {
            target.y = s.bounds.y + s.width;
        } else if (crossed.bottom) {
            target.y = s.bounds.y + s.bounds.height - s.width;
        }
    }
    pub fn checkIntersection(s: *@This(), other: *@This()) ?rl.Vector2 {
        const d = s.width + other.width;
        if (s.position.distanceSqr(other.position) <= d * d) {
            //const prop = (s.width / other.width) * 2;
            return rl.Vector2.init(
                (s.position.x + other.position.x) / 2,
                (s.position.y + other.position.y) / 2,
            );
        } else return null;
    }

    pub fn checkRayColision(s: *@This(), o: *@This(), delta: f32) ?rl.Vector2 {
        const transform_vec = s.force.rotate(std.math.pi / 2.0).normalize().scale(s.width);
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
    pub fn getNextPosition(s: *@This(), delta: f32) rl.Vector2 {
        const scaler = s.getDeltaScaler(delta);
        const vec = s.force.scale(scaler);
        return s.position.add(vec);
    }

    pub fn applyCollision(a: *@This(), b: *@This(), r: f32) void {
        const delta = a.position.subtract(b.position);
        const d = delta.length();
        const mtd = delta.scale((a.width + b.width - d) / d);
        const im_a = 1 / a.mass;
        const im_b = 1 / b.mass;
        const iim = 1 / (im_a + im_b);

        a.position = a.position.add(mtd.scale(im_a * iim));
        b.position = b.position.subtract(mtd.scale(im_b * iim));

        const v = a.force.subtract(b.force);
        const mtd_norm = mtd.normalize();

        const vn = v.dotProduct(mtd_norm);

        if (vn >= 0) return;

        const i = -(vn + r) * iim;
        const impulse = mtd_norm.scale(i);

        a.force = a.force.add(impulse.scale(im_a));
        b.force = b.force.subtract(impulse.scale(im_b));
    }
};
pub fn update(s: *@This(), offset: rl.Vector2, scale: f32, delta: f32) void {
    s.state.applyMouseAction(offset, scale);
    var target = s.state.getNextPosition(delta);
    s.state.applyBoundryColisions(&target);
    s.state.position = target;
}

pub fn init(boundry: *rl.Rectangle) @This() {
    return .{ .state = .init(boundry) };
}
pub fn draw(s: *@This(), offset: rl.Vector2, scale: f32) void {
    rl.drawRing(
        s.state.position.scale(scale).add(offset),
        s.state.width * scale,
        (s.state.width + s.border_width) * scale,
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
