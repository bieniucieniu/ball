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

pub const State = struct {
    position: rl.Vector2 = .init(0, 0),
    force: rl.Vector2 = .init(0, 0),
    width: f32 = 12,
    mass: f32 = 30,
    boundry: *rl.Vector4,
    is_hold: bool = false,
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
    fn applyMouseAction(s: *@This()) void {
        const mouse = getMouse(rl.getMousePosition(), s.boundry.*);
        const mouse_down = rl.isMouseButtonDown(.left);
        if (mouse_down) {
            if (mouse.distance(s.position) < s.width or s.is_hold) {
                s.force = mouse.subtract(s.position);
                s.is_hold = true;
            }
        } else s.is_hold = false;
    }
    fn applyBoundryColisions(s: *@This(), target: *rl.Vector2) void {
        const crossed = s.boundriesCrossed(target.*);
        if ((crossed.left and s.force.x < 0) or (crossed.right and s.force.x > 0)) s.force.x = -s.force.x;
        if ((crossed.top and s.force.y < 0) or (crossed.bottom and s.force.y > 0)) s.force.y = -s.force.y;

        if (crossed.left) {
            target.x = s.boundry.x + s.width;
        } else if (crossed.right) {
            target.x = s.boundry.z - s.width;
        }
        if (crossed.top) {
            target.y = s.boundry.y + s.width;
        } else if (crossed.bottom) {
            target.y = s.boundry.w - s.width;
        }
        // return .{
        //     .{
        //         .x = if ((crossed.left and s.force.x < 0) or (crossed.right and s.force.x > 0)) -s.force.x else s.force.x,
        //         .y = if ((crossed.top and s.force.y < 0) or (crossed.bottom and s.force.y > 0)) -s.force.y else s.force.x,
        //     },
        //     .{
        //         .x = if (crossed.left)
        //             s.boundry.x + s.width
        //         else if (crossed.right)
        //             s.boundry.z - s.width
        //         else
        //             target.x,
        //         .y = if (crossed.top)
        //             s.boundry.y + s.width
        //         else if (crossed.bottom)
        //             s.boundry.w - s.width
        //         else
        //             target.y,
        //     },
        // };

        //std.debug.print("{}\n{}\n{}\n{}\n\n", .{ crossed, target.*, s.boundry, s.loopstate });
    }

    fn applyColision(s: *@This(), other: *@This()) void {
        s.position.subtract(other.*);
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
        const scaler = s.getScaler(delta);
        const vec = s.force.scale(scaler);
        return s.position.add(vec);
    }

    pub fn applyCollision(a: *@This(), b: *@This(), r: f32) void {
        const delta = a.position.subtract(b.position);
        const d = delta.length();
        const mtd = delta.scale((a.width + b.width - d) / d);
        const im_a = 1 / a.mass;
        const im_b = 1 / b.mass;

        a.position = a.position.add(mtd.scale(im_a * (a.mass + b.mass)));
        b.position = b.position.subtract(mtd.scale(im_b * (a.mass + b.mass)));

        const v = a.force.subtract(b.force);
        const mtd_norm = mtd.normalize();

        const vn = v.dotProduct(delta);

        if (vn > 0) return;

        const i = -(vn * r) / (im_a + im_b);
        const impulse = mtd_norm.scale(i);

        a.force = a.force.add(impulse.scale(im_a));
        b.force = b.force.subtract(impulse.scale(im_b));
    }
    pub fn applyCollision2(a: *@This(), b: *@This(), r: f32, delta: f32) void {
        const s = a.getScaler(delta);
        var af = a.force.scale(s);
        var bf = b.force.scale(s);
        const pba = b.position.subtract(a.position);
        // x21=x2-x1;
        // y21=y2-y1;

        const vba = bf.subtract(af);
        // vx21=vx2-vx1;
        // vy21=vy2-vy1;

        if (vba.dotProduct(pba) >= 0) return;
        //if ((vx21 * x21 + vy21 * y21) >= 0) return;

        const mba = b.mass / a.mass;
        // m21=m2/m1;

        // vx_cm = (m1*vx1+m2*vx2)/(m1+m2) ;
        // vy_cm = (m1*vy1+m2*vy2)/(m1+m2) ;

        {
            const tmp = 1.0E-12 * @abs(pba.y);
            if (@abs(pba.x) < tmp)
                af.x = if (pba.x < 0) -tmp else tmp;
        }
        // fy21 = 1.0E-12 * fabs(y21);
        // if (fabs(x21) < fy21) {
        //     if (x21 < 0) {
        //         sign = -1;
        //     } else {
        //         sign = 1;
        //     }
        //     x21 = fy21 * sign;
        // }

        const aa = pba.y / pba.x;
        // a=y21/x21;

        // dvx2= -2*(vx21 +a*vy21)/((1+a*a)*(1+m21)) ;
        const dv = -2 * (vba.x + aa * vba.y) / ((1 + (aa * aa)) * (1 + mba));

        // vx2=vx2+dvx2;
        // vy2=vy2+a*dvx2;
        const bfp: rl.Vector2 = .{
            .x = bf.x + dv,
            .y = bf.y + aa * dv,
        };
        std.debug.print("bf: {} bfp: {} \ndv: {} aa: {}  dot: {} \n", .{ b.force, bfp, dv, aa, bf.dotProduct(bfp) });
        b.force = bfp;

        // vx1=vx1-m21*dvx2;
        // vy1=vy1-a*m21*dvx2;
        const afp: rl.Vector2 = .{
            .x = af.x - mba * dv,
            .y = af.y - aa * mba * dv,
        };
        a.force = afp;

        //_ = r;
        const v_cm = (af.scale(a.mass).add(bf.scale(b.mass))).scale(1 / (a.mass + b.mass));
        // ***  velocity correction for inelastic collisions ***
        a.force = af.subtract(v_cm).scale(r).add(v_cm);
        // vx1=(vx1-vx_cm)*R + vx_cm;
        // vy1=(vy1-vy_cm)*R + vy_cm;

        b.force = bf.subtract(v_cm).scale(r).add(v_cm);
        // vx2=(vx2-vx_cm)*R + vx_cm;
        // vy2=(vy2-vy_cm)*R + vy_cm;
    }
};
pub fn update(s: *@This(), delta: f32) void {
    s.state.applyMouseAction();
    var target = s.state.getNextPosition(delta);
    s.state.applyBoundryColisions(&target);
    s.state.position = target;
}

pub fn init(boundry: *rl.Vector4) @This() {
    return .{ .state = .init(boundry) };
}
pub fn draw(s: *@This()) void {
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
