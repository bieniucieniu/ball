const rl = @import("raylib");
const std = @import("std");

pub const BallState = struct {
    position: rl.Vector2 = .init(0, 0),
    target_positon: rl.Vector2 = .init(0, 0),
    force: f32 = 0.08,
    boundry: rl.Vector4 = .init(0, 0, std.math.floatMax(f32), std.math.floatMax(f32)),
    color: rl.Color = .white,
    border_color: rl.Color = .gray,
    width: f32 = 24,
    border_width: f32 = 2,
    is_hold: bool = false,

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
        const mouse = s.getMouse(rl.getMousePosition());
        const mouse_down = rl.isMouseButtonDown(.left);
        if (mouse_down) {
            if (mouse.distance(s.position) < s.width or s.is_hold) {
                s.is_hold = true;
                s.target_positon = mouse;
            }
        } else s.is_hold = false;

        s.position = s.target_positon
            .subtract(s.position)
            .scale(s.force)
            .add(s.position);
        // s.position.x += (s.mouse.x - s.position.x) * s.force;
        // s.position.y += (s.mouse.y - s.position.y) * s.force;
    }
    pub fn init() @This() {
        return .{};
    }
    pub fn draw(s: *@This()) void {
        rl.drawLine(
            @intFromFloat(s.position.x),
            @intFromFloat(s.position.y),
            @intFromFloat(s.target_positon.x),
            @intFromFloat(s.target_positon.y),
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
