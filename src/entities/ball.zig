const rl = @import("raylib");
const std = @import("std");
const loop = @import("../loop.zig");

pub const BallState = struct {
    position: rl.Vector2 = .init(0, 0),
    force: rl.Vector2 = .init(0, 0),
    loopstate: *loop.LoopState,
    friction: f32 = 0.001,
    boundry: *rl.Vector4,
    color: rl.Color = .white,
    border_color: rl.Color = .gray,
    width: f32 = 12,
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

    const BoundiesCrossed = packed struct(u4) {
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
    fn boundriesCrossed(s: *@This(), target: rl.Vector2) BoundiesCrossed {
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
        const m: f32 = 30;
        const per_s =
            if (s.loopstate.delta != 0)
                s.loopstate.delta * m
            else
                m / @as(f32, @floatFromInt(s.loopstate.tickrate.current));
        return per_s;
    }
    pub fn update(s: *@This(), allow_interaction: bool) void {
        const mouse = s.getMouse(rl.getMousePosition());
        const mouse_down = rl.isMouseButtonDown(.left);
        if (mouse_down and allow_interaction) {
            if (mouse.distance(s.position) < s.width or s.is_hold) {
                s.is_hold = true;
                s.force = mouse.subtract(s.position);
            }
        } else s.is_hold = false;
        s.applyFriction();
        const scaler = s.getScaler();
        const vec = s.force.scale(scaler);

        const target = s.position.add(vec);
        const crossed = s.boundriesCrossed(target);
        if ((crossed.left and s.force.x < 0) or (crossed.right and s.force.x > 0)) s.force.x = -s.force.x;
        if ((crossed.top and s.force.y < 0) or (crossed.bottom and s.force.y > 0)) s.force.y = -s.force.y;

        // if (crossed.left) target.x = 2 * s.boundry.x - target.x;
        // if (crossed.right) target.x = 2 * s.boundry.z - target.x;
        // if (crossed.top) target.y = 2 * s.boundry.y - target.y;
        // if (crossed.bottom) target.y = 2 * s.boundry.w - target.y;

        // if (@as(u4, @bitCast(crossed)) != 0)
        //     std.debug.print("scaler({})\ncrossed{}\nforce{}\nw={}\npos{}\nt{}\nboundry{}\n\n", .{
        //         scaler,
        //         crossed,
        //         s.force,
        //         s.width,
        //         s.position,
        //         target,
        //         s.boundry,
        //     });

        s.position = target;

        // s.position.x += (s.mouse.x - s.position.x) * s.force;
        // s.position.y += (s.mouse.y - s.position.y) * s.force;
    }
    pub fn init(loopstate: *loop.LoopState, boundry: *rl.Vector4) @This() {
        return .{ .loopstate = loopstate, .boundry = boundry };
    }
    pub fn draw(s: *@This()) void {
        const force = s.force;
        rl.drawLine(
            @intFromFloat(s.position.x),
            @intFromFloat(s.position.y),
            @intFromFloat(s.position.x + force.x),
            @intFromFloat(s.position.y + force.y),
            s.border_color,
        );
        rl.drawCircle(
            @intFromFloat(s.position.x),
            @intFromFloat(s.position.y),
            s.width + s.border_width,
            s.border_color,
        );
        rl.drawCircle(
            @intFromFloat(s.position.x),
            @intFromFloat(s.position.y),
            s.width,
            s.color,
        );
    }
};
