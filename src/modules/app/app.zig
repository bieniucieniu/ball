const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");
const meta = std.meta;
const Shared = @import("../shared.zig");
const Loop = Shared.Loop;
const Options = Shared.Options;
const BallsState = @import("../free-moving-balls/free-moving-balls.zig");

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
options: Options = .{},
state: StateType = .{ .none = undefined },
backgroup_color: rl.Color = .white,
message_cannel: Shared.BufferedChan(Message) = .{},

const Message = union(enum) {
    none,
    swap_background,
    reset,
    set_balls: usize,
    set_none,
};

pub fn swapBackgroud(self: *@This()) void {
    const eqls = meta.eql(self.backgroup_color, .white);
    self.backgroup_color = if (eqls) .black else .white;
}

pub fn configurate(s: *@This(), alloc: std.mem.Allocator, options: Options) !void {
    if (options.help) {
        try Options.printHelp(.stdout());
        std.process.exit(0);
        return;
    }
    s.options = options;

    switch (options.mode) {
        .ball => try s.setState(alloc, .{ .ball = .{} }),
        .none => try s.setState(alloc, .{ .none = undefined }),
    }
}
pub fn setState(s: *@This(), alloc: std.mem.Allocator, t: StateArgs) !void {
    s.deinitState(alloc);
    switch (t) {
        .ball => {
            var count = t.ball.count;
            if (count == 0) count = s.options.count;
            s.state = .{ .ball = try .init(alloc, count) };
            s.state.ball.updateBoundry(s.width, s.height);
            try s.state.ball.appendBalls(alloc, count);
        },
        .none => s.state = .{ .none = undefined },
    }
}
pub fn deinitState(s: *@This(), alloc: std.mem.Allocator) void {
    switch (s.state) {
        .ball => s.state.ball.deinit(alloc),
        .none => {},
    }
}
pub fn deinit(s: *@This(), alloc: std.mem.Allocator) void {
    s.deinitState(alloc);
}
pub fn update(s: *@This(), alloc: std.mem.Allocator, delta: f32) void {
    s.width = rl.getScreenWidth();
    s.height = rl.getScreenHeight();
    switch (s.state) {
        .ball => {
            //s.state.ball.updateBoundry(s.width, s.height);
            s.state.ball.balls_boundry = .init(20, 64, @floatFromInt(s.width - 20), @floatFromInt(s.height - 20));
            s.state.ball.update(alloc, delta);
        },
        else => {},
    }
}
// alloc should be removed from draw
pub inline fn draw(s: *@This(), _: std.mem.Allocator) void {
    rl.clearBackground(s.backgroup_color);
    if (rg.button(.init(24, 24, 120, 24), "btn")) s.swapBackgroud();
    if (rg.button(.init(160, 24, 120, 24), "ball")) {
        s.message_cannel.send(.{ .set_balls = 0 });
        // switch (s.state) {
        //     .ball => s.reset() catch {},
        //     // alloc should be removed from draw
        //     else => s.setState(alloc, .{ .ball = .{} }) catch {},
        // }
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
