const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");
const meta = std.meta;
const Shared = @import("../shared.zig");
const Loop = Shared.Loop;
const Options = Shared.Options;
const BallsState = @import("../free-moving-balls/free-moving-balls.zig");

const StateEnum = enum { ball };
const StateArgs = union(StateEnum) {
    ball: struct { count: usize = 0 },
};
const StateType = union(StateEnum) {
    ball: BallsState,

    pub fn deinit(s: *@This(), alloc: std.mem.Allocator) void {
        switch (s.*) {
            .ball => |*b| b.deinit(alloc),
        }
    }
    pub inline fn draw(s: *@This()) void {
        switch (s.*) {
            .ball => |*b| b.draw(),
        }
    }
    pub fn update(s: *@This(), alloc: std.mem.Allocator, boundry: rl.Vector4, delta: f32) void {
        switch (s.*) {
            .ball => |*b| {
                b.balls_boundry = boundry;
                b.update(alloc, delta);
            },
        }
    }

    pub fn reset(s: *@This()) !void {
        switch (s.*) {
            .ball => |*b| try b.reset(),
        }
    }
};
width: i32 = 800,
height: i32 = 450,
options: Options = .{},
state: ?*StateType = null,
state_mutex: std.Thread.Mutex = .{},
backgroup_color: rl.Color = .white,
messanger: Shared.MessageQueue(Message, .{ .buffer_size = 256 }) = .{},
alloc: std.mem.Allocator,

const Message = union(enum) {
    swap_background,
    reset,
    set_balls: usize,
    set_none,
};

pub fn swapBackgroud(self: *@This()) void {
    const eqls = meta.eql(self.backgroup_color, .white);
    self.backgroup_color = if (eqls) .black else .white;
}
pub fn init(alloc: std.mem.Allocator) @This() {
    return .{ .alloc = alloc };
}

pub fn configurate(s: *@This(), options: Options) !void {
    if (options.help) {
        try Options.printHelp(.stdout());
        std.process.exit(0);
        return;
    }
    s.options = options;

    switch (options.mode) {
        .ball => try s.setState(.{ .ball = .{} }),
        .none => try s.setState(null),
    }
}
pub fn setState(s: *@This(), args: ?StateArgs) !void {
    s.state_mutex.lock();
    defer s.state_mutex.unlock();

    const prev = s.state;
    defer if (prev) |p| {
        p.deinit(s.alloc);
        s.alloc.destroy(p);
    };
    if (args) |t| {
        switch (t) {
            .ball => {
                var count = t.ball.count;
                if (count == 0) count = s.options.count;

                var ptr = try s.alloc.create(StateType);
                errdefer s.alloc.destroy(ptr);

                ptr.* = .{ .ball = try .init(s.alloc, count) };
                errdefer ptr.deinit(s.alloc);

                ptr.ball.updateBoundry(s.width, s.height);
                try ptr.ball.appendBalls(s.alloc, count);

                s.state = ptr;
            },
        }
    } else {
        s.state = null;
    }
}

pub fn deinit(s: *@This()) void {
    if (s.state) |st| {
        st.deinit(s.alloc);
        s.alloc.destroy(st);
    }
}
pub fn update(s: *@This(), delta: f32) void {
    s.width = rl.getScreenWidth();
    s.height = rl.getScreenHeight();

    while (s.messanger.receive()) |msg| {
        switch (msg) {
            .swap_background => s.swapBackgroud(),
            .reset => s.reset() catch {},
            .set_balls => s.setState(.{ .ball = .{ .count = msg.set_balls } }) catch {},
            .set_none => s.setState(null) catch {},
        }
    } else {}

    if (s.state) |state| state.update(
        s.alloc,
        .init(
            20,
            64,
            @floatFromInt(s.width - 20),
            @floatFromInt(s.height - 20),
        ),
        delta,
    );
}
// alloc should be removed from draw
pub inline fn draw(s: *@This()) void {
    s.state_mutex.lock();
    defer s.state_mutex.unlock();
    rl.clearBackground(s.backgroup_color);
    if (rg.button(.init(24, 24, 120, 24), "btn")) s.swapBackgroud();
    if (rg.button(.init(160, 24, 120, 24), "ball")) {
        s.messanger.send(.{ .set_balls = 0 }) catch {};
        // switch (s.state) {
        //     .ball => s.reset() catch {},
        //     // alloc should be removed from draw
        //     else => s.setState(alloc, .{ .ball = .{} }) catch {},
        // }
    }

    if (s.state) |state| state.draw();
}
pub fn reset(s: *@This()) !void {
    if (s.state) |*state| try state.*.reset();
}
