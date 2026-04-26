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
    ball: struct { count: ?usize = null },
};
const StateType = union(StateEnum) {
    ball: BallsState,

    pub fn deinit(s: *@This(), alloc: std.mem.Allocator) void {
        switch (s.*) {
            .ball => |*b| b.deinit(alloc),
        }
    }
    pub inline fn draw(s: *@This(), bounds: rl.Rectangle) void {
        switch (s.*) {
            .ball => |*b| b.draw(bounds),
        }
    }
    pub fn update(s: *@This(), alloc: std.mem.Allocator, delta: f32) void {
        switch (s.*) {
            .ball => |*b| {
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
state_mutex: std.Io.Mutex = .init,
backgroup_color: rl.Color = .white,
event_queue: Shared.Queue(Event, .{
    .buffer_size = 256,
    .overflow_policy = .drop_newest,
}) = .{},
alloc: std.mem.Allocator,
io: std.Io,

const Event = union(enum) {
    swap_background,
    reset,
    set_balls: usize,
    set_none,
};

pub fn swapBackgroud(self: *@This()) void {
    const eqls = meta.eql(self.backgroup_color, .white);
    self.backgroup_color = if (eqls) .black else .white;
}
pub fn init(alloc: std.mem.Allocator, io: std.Io) @This() {
    return .{ .alloc = alloc, .io = io };
}

pub fn configurate(s: *@This(), options: Options) !void {
    if (options.help) {
        try Options.printHelp(s.io, .stdout());
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
    try s.state_mutex.lock(s.io);
    defer s.state_mutex.unlock(s.io);

    const prev = s.state;
    defer if (prev) |p| {
        p.deinit(s.alloc);
        s.alloc.destroy(p);
    };
    if (args) |t| {
        switch (t) {
            .ball => |b| {
                const count = if (b.count) |c| c else s.options.count;

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

    while (s.event_queue.receive()) |msg| {
        switch (msg) {
            .swap_background => s.swapBackgroud(),
            .reset => s.reset() catch {},
            .set_balls => s.setState(.{ .ball = .{ .count = msg.set_balls } }) catch {},
            .set_none => s.setState(null) catch {},
        }
    } else {}

    if (s.state) |state| state.update(s.alloc, delta);
}

const max_float_from_usize = @as(f32, @floatFromInt(std.math.maxInt(usize)));

pub inline fn draw(s: *@This()) void {
    s.state_mutex.lock();
    defer s.state_mutex.unlock();
    rl.clearBackground(s.backgroup_color);
    if (rg.button(.init(24, 24, 120, 24), "btn")) s.swapBackgroud();
    if (rg.button(.init(160, 24, 120, 24), "ball")) {
        s.event_queue.send(.{ .set_balls = 0 }) catch {};
    }

    var count: f32 = blk: {
        if (s.state) |state| {
            switch (state.*) {
                .ball => |*b| break :blk @floatFromInt(b.balls.items.len),
            }
        }
        break :blk 0;
    };

    if (rg.slider(.init(24, 56, 120, 24), rl.textFormat("%d", .{count}), "1000", &count, 0, 1000) > 0) {
        if (count > max_float_from_usize) count = max_float_from_usize;
        s.event_queue.send(.{ .set_balls = @intFromFloat(count) }) catch {};
    }

    if (s.state) |state| state.draw(.init(
        24,
        96,
        @floatFromInt(s.width - 48),
        @floatFromInt(s.height - (96 + 24)),
    ));
}
pub fn reset(s: *@This()) !void {
    if (s.state) |*state| try state.*.reset();
}
