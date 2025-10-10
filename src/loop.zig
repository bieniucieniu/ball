const std = @import("std");
const rl = @import("raylib");

pub const RateState = packed struct {
    current: i32 = 0,
    hight: i32 = 120,
    low: i32 = 10,

    pub fn copy(self: *@This(), other: *const @This()) void {
        self.current = other.current;
        self.hight = other.hight;
        self.low = other.low;
    }
    pub fn getScaler(self: *@This()) f32 {
        return 1 / @as(f32, @floatFromInt(self.current));
    }
};

pub const LoopState = struct {
    framerate: RateState = .{},
    tickrate: RateState = .{},

    timer: std.time.Timer,
    last_time: u64,
    /// delta time secends
    delta: f32 = 0,
    focused: bool = true,

    pub fn update(self: *@This()) void {
        const new_time = self.timer.read();
        self.delta = @as(f32, @floatFromInt(new_time - self.last_time)) / std.time.ns_per_s;
        self.last_time = new_time;
        const current_focused = rl.isWindowFocused();
        if (self.focused != current_focused) {
            self.focused = current_focused;
        }
        self.updateTickreate(self.tickrate);
        self.updateFramerate(self.framerate);
    }

    pub fn updateTickreate(self: *@This(), new: RateState) void {
        self.tickrate.copy(&new);
        self.tickrate.current = if (self.focused) self.tickrate.hight else self.tickrate.low;
    }

    pub fn updateFramerate(self: *@This(), new: RateState) void {
        const pre = self.framerate;
        self.framerate.copy(&new);
        self.framerate.current = if (self.focused) self.framerate.hight else self.framerate.low;
        if (!std.meta.eql(pre, self.framerate)) {
            rl.setTargetFPS(self.framerate.current);
        }
    }

    fn getTickrateDelta(self: *@This()) f64 {
        return 1 / @as(f64, @floatFromInt(self.tickrate.current));
    }
    pub fn sleepToNext(self: *@This()) void {
        const delta = self.timer.read() - self.last_time;
        const duration = (@as(f64, @floatFromInt(delta)) / std.time.ns_per_s);
        const time_to_next_frame = self.getTickrateDelta() - duration;
        if (time_to_next_frame > 0) {
            const d = time_to_next_frame * std.time.ns_per_s;
            std.Thread.sleep(@as(u64, @intFromFloat(d)));
        }
    }
    pub fn init() LoopState {
        var timer = std.time.Timer.start() catch unreachable;
        return .{ .timer = timer, .last_time = timer.read() };
    }
};
