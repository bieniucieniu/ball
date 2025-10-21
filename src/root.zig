const rl = @import("raylib");
const rg = @import("raygui");
const std = @import("std");
const LoopState = @import("./modules/shared/loop/loop.zig");
const BallsState = @import("./modules/free-moving-balls/main.zig");
const meta = std.meta;
const bufPrint = std.fmt.bufPrint;

fn getArgsNextInt(args: *std.process.ArgIterator) !usize {
    const a = args.next() orelse return error.Null;
    return try std.fmt.parseInt(usize, std.mem.sliceTo(a, 0), 0);
}
pub fn run() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const allocator = gpa.allocator();

    var loopState: LoopState = .init();
    var state: AppState = try .init(allocator);
    defer state.deinit();

    //try state.appendBalls(count);

    rl.setConfigFlags(.{ .window_resizable = true });
    rl.initWindow(state.width, state.width, "yea");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(loopState.framerate.current);
    state.update(loopState.delta);
    var update_thread = try std.Thread.spawn(.{}, runUpdateLoop, .{ &loopState, &state });
    defer update_thread.detach();
    try runRenderLoop(&loopState, &state);
}

fn runRenderLoop(loop: *LoopState, state: *AppState) !void {
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.setWindowTitle(rl.textFormat("fps = %d tps = %f", .{ rl.getFPS(), 1 / loop.delta }));
        state.draw();
    }
}

fn runUpdateLoop(loop: *LoopState, state: *AppState) void {
    while (!rl.windowShouldClose()) {
        loop.update();
        defer loop.sleepToNext();
        state.update(loop.delta);
    }
}

const ParsedArgs = struct {
    count: usize = 2_000,
    args: std.process.ArgIterator,
    fn deinit(s: *@This()) void {
        s.args.deinit();
    }
};
fn parseArgs(allocator: std.mem.Allocator) !ParsedArgs {
    var args = try std.process.argsWithAllocator(allocator);
    _ = args.skip();
    const count: usize = getArgsNextInt(&args) catch 2_000;
    return .{
        .count = count,
        .args = args,
    };
}

const AppState = struct {
    const StateEnum = enum { ball, none };
    const StateArgs = union(StateEnum) {
        ball: struct { count: usize = 0 },
        none: struct {},
    };
    const StateType = union(StateEnum) {
        ball: BallsState,
        none: struct {},
    };
    width: i32 = 800,
    height: i32 = 450,
    args: ParsedArgs,
    allocator: std.mem.Allocator,
    state: StateType = .{ .none = undefined },
    backgroup_color: rl.Color = .white,

    pub fn swapBackgroud(self: *@This()) void {
        const eqls = meta.eql(self.backgroup_color, .white);
        self.backgroup_color = if (eqls) .black else .white;
    }
    fn init(allocator: std.mem.Allocator) !@This() {
        const args = try parseArgs(allocator);

        return .{
            .args = args,
            .allocator = allocator,
        };
    }
    fn setState(s: *@This(), t: StateArgs) !void {
        s.state = state: switch (t) {
            .ball => {
                var count = t.ball.count;
                if (count == 0) count = s.args.count;
                var ball: BallsState = try .init(s.allocator, count);
                ball.updateBoundry(s.width, s.height);
                try ball.appendBalls(count);
                break :state .{ .ball = ball };
            },
            .none => break :state undefined,
        };
    }
    fn deinit(s: *@This()) void {
        switch (s.state) {
            .ball => s.state.ball.deinit(),
            .none => {},
        }
        s.args.deinit();
    }
    pub fn update(s: *@This(), delta: f32) void {
        s.width = rl.getScreenWidth();
        s.height = rl.getScreenHeight();
        switch (s.state) {
            .ball => {
                s.state.ball.updateBoundry(s.width, s.height);
                s.state.ball.update(delta);
            },
            else => {},
        }
    }
    pub fn draw(s: *@This()) void {
        rl.clearBackground(s.backgroup_color);

        if (rg.button(.init(24, 24, 120, 24), "btn")) s.swapBackgroud();
        if (rg.button(.init(160, 24, 120, 24), "ball")) {
            switch (s.state) {
                .ball => s.reset() catch {},
                else => s.setState(.{ .ball = .{} }) catch {},
            }
        }

        switch (s.state) {
            .ball => s.state.ball.draw(),
            else => {},
        }
    }
    pub fn reset(s: *@This()) !void {
        switch (s.state) {
            .ball => try s.state.ball.reset(),
            else => {},
        }
    }
};
