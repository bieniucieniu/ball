const rl = @import("raylib");
const std = @import("std");

pub const BallState = struct {
    position: rl.Vector2 = .init(0, 0),
    mouse: rl.Vector2 = .init(0, 0),
    force: f32 = 0.2,
    boundry: rl.Vector4 = .init(0, 0, std.math.floatMax(f32), std.math.floatMax(f32)),
    color: rl.Color = .white,
    border_color: rl.Color = .gray,
    width: f32 = 24,
    border_width: f32 = 2,

    pub inline fn updateBoundry(
        s: *@This(),
        x: f32,
        y: f32,
        z: f32,
        w: f32,
    ) void {
        s.boundry = .init(x, y, z, w);
    }

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
    fn getMouse(s: *@This(), mouse: rl.Vector2) rl.Vector2 {
        return rl.Vector2.init(s.getMouseX(mouse), s.getMouseY(mouse));
    }
    pub fn update(s: *@This()) void {
        s.mouse = s.getMouse(rl.getMousePosition());
        s.position.x += std.math.pow(f32, (s.mouse.x - s.position.x), s.force);
        s.position.y += std.math.pow(f32, (s.mouse.y - s.position.y), s.force);
    }
    pub fn init() @This() {
        return .{};
    }
    pub fn draw(s: *@This()) void {
        rl.drawLine(
            @intFromFloat(s.position.x),
            @intFromFloat(s.position.y),
            @intFromFloat(s.mouse.x),
            @intFromFloat(s.mouse.y),
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
