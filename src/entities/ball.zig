const rl = @import("raylib");
const std = @import("std");

pub const BallState = struct {
    position: rl.Vector2 = .init(0, 0),
    force: rl.Vector2 = .init(0, 0),
    scale: f32 = 0.08,
    friction: f32 = 0.001,
    boundry: rl.Vector4 = .init(0, 0, std.math.floatMax(f32), std.math.floatMax(f32)),
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

    fn colisionBoundryH(s: *@This(), force: rl.Vector2) bool {
        const y = s.position.y + force.y;
        return (s.boundry.y > y - s.width or s.boundry.w < y + s.width);
    }
    fn colisionBoundryV(s: *@This(), force: rl.Vector2) bool {
        const x = s.position.x + force.x;
        return (s.boundry.x > x - s.width or s.boundry.z < x + s.width);
    }
    fn applyFriction(s: *@This()) void {
        s.force = s.force.scale(1 - s.friction * s.scale);
    }

    fn getMouse(s: *@This(), mouse: rl.Vector2) rl.Vector2 {
        return rl.Vector2.init(s.getMouseX(mouse), s.getMouseY(mouse));
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
        const v = s.force.scale(s.scale);
        if (s.colisionBoundryH(v)) {
            s.force.y = -s.force.y;
            s.applyFriction();
        }

        if (s.colisionBoundryV(v)) {
            s.force.x = -s.force.x;
            s.applyFriction();
        }

        s.position = s.position.moveTowards(
            s.force.scale(s.scale).add(s.position),
            s.width,
        );
        // s.position.x += (s.mouse.x - s.position.x) * s.force;
        // s.position.y += (s.mouse.y - s.position.y) * s.force;
    }
    pub fn init() @This() {
        return .{};
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
