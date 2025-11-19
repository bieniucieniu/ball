const std = @import("std");

const Options = struct {
    buffer_size: usize = 1024,
};

const MessageQueueSendError = error{
    OutOfBuffer,
    Locked,
};

pub fn MessageQueue(comptime T: type, comptime options: Options) type {
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
        pub fn send(s: *@This(), data: T) !void {
            s.mut.lock();
            defer s.mut.unlock();

            for (0..s.buffer.len - 1) |i| {
                const idx = (s.pivot + i) % s.buffer.len;
                std.debug.print("idx: {} i: {} len: {}\n", .{ idx, i, s.buffer.len });
                if (s.buffer[idx] == null) {
                    s.buffer[idx] = data;
                    return;
                }
            }
            return MessageQueueSendError.OutOfBuffer;
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
