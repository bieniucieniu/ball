const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");
const meta = std.meta;
const LoopState = @import("../shared/loop/loop.zig");
const BallsState = @import("../free-moving-balls/main.zig");

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
pub fn init(allocator: std.mem.Allocator) !@This() {
    const args = try parseArgs(allocator);

    return .{
        .args = args,
        .allocator = allocator,
    };
}
pub fn setState(s: *@This(), t: StateArgs) !void {
    s.deinitState();
    switch (t) {
        .ball => {
            var count = t.ball.count;
            if (count == 0) count = s.args.count;
            s.state = .{ .ball = try .init(s.allocator, count) };
            s.state.ball.updateBoundry(s.width, s.height);
            try s.state.ball.appendBalls(count);
        },
        .none => s.state = .{ .none = undefined },
    }
}
pub fn deinitState(s: *@This()) void {
    switch (s.state) {
        .ball => s.state.ball.deinit(),
        .none => {},
    }
}
pub fn deinit(s: *@This()) void {
    s.deinitState();
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
pub const ParsedArgs = struct {
    count: usize = 2_000,
    args: std.process.ArgIterator,
    fn deinit(s: *@This()) void {
        s.args.deinit();
    }
};
pub fn parseArgs(allocator: std.mem.Allocator) !ParsedArgs {
    var args = try std.process.argsWithAllocator(allocator);
    _ = args.skip();
    const count: usize = getArgsNextInt(&args) catch 2_000;
    return .{
        .count = count,
        .args = args,
    };
}
pub fn getArgsNextInt(args: *std.process.ArgIterator) !usize {
    const a = args.next() orelse return error.Null;
    return try std.fmt.parseInt(usize, std.mem.sliceTo(a, 0), 0);
}
