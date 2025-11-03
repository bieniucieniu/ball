const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");
const meta = std.meta;
const Shared = @import("../shared.zig");
const Loop = Shared.Loop;
const Cli = Shared.Cli;
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
options: Cli,
state: StateType = .{ .none = undefined },
backgroup_color: rl.Color = .white,

pub fn swapBackgroud(self: *@This()) void {
    const eqls = meta.eql(self.backgroup_color, .white);
    self.backgroup_color = if (eqls) .black else .white;
}
pub fn init(allocator: std.mem.Allocator) !@This() {
    const options = try Cli.create(allocator, .{});
    if (options.help) {
        try Cli.printHelp(.stdout());
        std.process.exit(0);
    }

    return .{
        .options = options,
    };
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
            s.state.ball.updateBoundry(s.width, s.height);
            s.state.ball.update(alloc, delta);
        },
        else => {},
    }
}
// alloc should be removed from draw
pub inline fn draw(s: *@This(), alloc: std.mem.Allocator) void {
    rl.clearBackground(s.backgroup_color);

    if (rg.button(.init(24, 24, 120, 24), "btn")) s.swapBackgroud();
    if (rg.button(.init(160, 24, 120, 24), "ball")) {
        switch (s.state) {
            .ball => s.reset() catch {},
            // alloc should be removed from draw
            else => s.setState(alloc, .{ .ball = .{} }) catch {},
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
