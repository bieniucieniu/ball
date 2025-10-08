const rl = @import("raylib");
const rg = @import("raygui");
const std = @import("std");
const meta = std.meta;
const bufPrint = std.fmt.bufPrint;

pub fn run() !void {
    // Initialization
    //--------------------------------------------------------------------------------------
    //
    var state: MainState = .init();

    rl.setConfigFlags(.{
        .window_resizable = true,
    });
    rl.initWindow(state.width, state.width, "raylib-zig [core] example - basic window");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------
    //

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        state.updateState();
        rl.beginDrawing();
        defer rl.endDrawing();
        try state.draw();
    }
}

const MainState = struct {
    width: i32 = 800,
    height: i32 = 450,
    backgroupColor: rl.Color = .white,
    ball: BallSate,

    fn updateState(self: *@This()) void {
        self.width = rl.getScreenWidth();
        self.height = rl.getScreenHeight();
        self.ball.updateBoundry(20, 20, @floatFromInt(self.width - 20), @floatFromInt(self.height - 20));
        self.ball.updateState();
    }
    fn swapBackgroud(self: *@This()) void {
        const eqls = meta.eql(self.backgroupColor, .white);
        self.backgroupColor = if (eqls) .black else .white;
    }

    fn init() @This() {
        return .{ .ball = .init() };
    }
    fn draw(s: *@This()) !void {
        if (rg.button(.init(24, 24, 120, 24), "btn")) s.swapBackgroud();

        rl.clearBackground(s.backgroupColor);
        const txt = rl.textFormat("mouse = .{.x = %.0f, .y = %.0f} mouse.y = .{.x = %.0f, .y = %.0f}", .{ s.ball.mouse.x, s.ball.mouse.y, s.ball.position.x, s.ball.position.y });
        rl.setWindowTitle(txt);
        //rl.drawText(txt, 180, 200, 20, .light_gray);
        try s.ball.draw();
    }
};

const BallSate = struct {
    position: rl.Vector2 = .init(0, 0),
    mouse: rl.Vector2 = .init(0, 0),
    force: f32 = 32,
    boundry: rl.Vector4 = .init(0, 0, std.math.floatMax(f32), std.math.floatMax(f32)),
    color: rl.Color = .white,
    borderColor: rl.Color = .gray,
    width: f32 = 24,
    borderWidth: f32 = 2,

    inline fn updateBoundry(
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
    fn updateState(s: *@This()) void {
        s.mouse = s.getMouse(rl.getMousePosition());
        s.position.x += (s.mouse.x - s.position.x) / s.force;
        s.position.y += (s.mouse.y - s.position.y) / s.force;
    }
    fn init() @This() {
        return .{};
    }
    fn draw(s: *@This()) !void {
        rl.drawLine(
            @intFromFloat(s.position.x),
            @intFromFloat(s.position.y),
            @intFromFloat(s.mouse.x),
            @intFromFloat(s.mouse.y),
            s.borderColor,
        );
        rl.drawCircle(
            @intFromFloat(s.position.x),
            @intFromFloat(s.position.y),
            s.width + s.borderWidth,
            s.borderColor,
        );
        rl.drawCircle(
            @intFromFloat(s.position.x),
            @intFromFloat(s.position.y),
            s.width,
            s.color,
        );
    }
};
