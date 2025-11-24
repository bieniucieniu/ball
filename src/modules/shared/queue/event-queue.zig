const std = @import("std");

pub const OverflowPolicy = enum {
    drop_oldest,
    drop_newest,
    none,
};

pub const Options = struct {
    buffer_size: usize = 1024,
    overflow_policy: OverflowPolicy = .none,
};

pub const EventQueueSendError = error{
    OutOfBuffer,
    Locked,
};

pub fn EventQueue(comptime T: type, comptime options: Options) type {
    return struct {
        pub const Buffer = [options.buffer_size]?T;

        buffer: Buffer = [_]?T{null} ** options.buffer_size,
        mut: std.Thread.Mutex = .{},
        pivot: usize = 0,

        pub fn receive(s: *@This()) ?T {
            s.mut.lock();
            defer s.mut.unlock();

            const val = s.buffer[s.pivot] orelse return null;
            s.buffer[s.pivot] = null;
            s.pivot = (s.pivot + 1) % s.buffer.len;

            return val;
        }
        pub fn send(s: *@This(), data: T) EventQueueSendError!void {
            s.mut.lock();
            defer s.mut.unlock();

            var idx: usize = 0;

            for (0..s.buffer.len - 1) |i| {
                idx = (s.pivot + i) % s.buffer.len;
                if (s.buffer[idx] == null) {
                    s.buffer[idx] = data;
                    return;
                }
            }

            switch (options.overflow_policy) {
                .drop_oldest => {
                    idx = (s.pivot + s.buffer.len - 1) % s.buffer.len;
                    s.buffer[idx] = data;
                },
                .drop_newest => {
                    idx = (s.pivot + 1) % s.buffer.len;
                    s.buffer[idx] = data;
                },
                .none => {
                    return EventQueueSendError.OutOfBuffer;
                },
            }
        }
        pub fn len(s: *@This()) usize {
            var count: usize = 0;
            for (0..s.buffer.len - 1) |i| {
                const idx = (s.pivot + i) % s.buffer.len;
                if (s.buffer[idx] != null) {
                    count += 1;
                }
            }

            return count;
        }
    };
}
