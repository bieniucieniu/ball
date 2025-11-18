const std = @import("std");

const ChanError = error{
    Closed,
    OutOfMemory,
    NotImplemented,
    DataCorruption,
};

fn Chan(comptime T: type) type {
    return BufferedChan(T, 0);
}

fn BufferedChan(comptime T: type, comptime bufSize: u8) type {
    return struct {
        const Self = @This();
        const bufType = [bufSize]?T;
        buf: bufType = [_]?T{null} ** bufSize,
        closed: bool = false,
        mut: std.Thread.Mutex = .{},
        alloc: std.mem.Allocator,
        recvQ: std.ArrayListUnmanaged(*Receiver) = .{},
        sendQ: std.ArrayListUnmanaged(*Sender) = .{},

        const Receiver = struct {
            mut: std.Thread.Mutex = std.Thread.Mutex{},
            cond: std.Thread.Condition = std.Thread.Condition{},
            data: ?T = null,

            fn putDataAndSignal(self: *@This(), data: T) void {
                defer self.cond.signal();
                self.data = data;
            }
        };

        const Sender = struct {
            mut: std.Thread.Mutex = std.Thread.Mutex{},
            cond: std.Thread.Condition = std.Thread.Condition{},
            data: T,

            fn getDataAndSignal(self: *@This()) T {
                defer self.cond.signal();
                return self.data;
            }
        };

        fn init(alloc: std.mem.Allocator) Self {
            return Self{
                .alloc = alloc,
            };
        }

        fn deinit(self: *Self) void {
            self.recvQ.deinit(self.alloc);
            self.sendQ.deinit(self.alloc);
        }

        fn close(self: *Self) void {
            self.closed = true;
        }

        fn capacity(self: *Self) u8 {
            return self.buf.len;
        }

        fn debugBuf(self: *Self) void {
            std.debug.print("{d} Buffer debug\n", .{std.time.milliTimestamp()});
            for (self.buf, 0..) |item, i| {
                if (item) |unwrapped| {
                    std.debug.print("[{d}] = {d}\n", .{ i, unwrapped });
                }
            }
        }

        fn len(self: *Self) u8 {
            var i: u8 = 0;
            for (self.buf) |item| {
                if (item) |_| {
                    i += 1;
                } else {
                    break;
                }
            }
            return i;
        }

        fn send(self: *Self, data: T) ChanError!void {
            if (self.closed) return ChanError.Closed;

            self.mut.lock();
            errdefer self.mut.unlock();

            if (self.recvQ.items.len > 0) {
                defer self.mut.unlock();
                var receiver: *Receiver = self.recvQ.orderedRemove(0);
                receiver.putDataAndSignal(data);
                return;
            }

            const l = self.len();
            if (l < self.capacity() and bufSize > 0) {
                defer self.mut.unlock();

                self.buf[l] = data;
                return;
            }

            var sender = Sender{ .data = data };

            sender.mut.lock();
            defer sender.mut.unlock();

            try self.sendQ.append(self.alloc, &sender);
            self.mut.unlock();
            sender.cond.wait(&sender.mut);
            return;
        }

        fn recv(self: *Self) ChanError!T {
            if (self.closed) return ChanError.Closed;
            self.mut.lock();
            errdefer self.mut.unlock();

            const l = self.len();
            if (l > 0 and bufSize > 0) {
                defer self.mut.unlock();
                const val = self.buf[0] orelse return ChanError.DataCorruption;

                if (l > 1) {
                    for (self.buf[1..l], 0..l - 1) |item, i| {
                        self.buf[i] = item;
                    }
                }
                self.buf[l - 1] = null;

                if (self.sendQ.items.len > 0) {
                    var sender: *Sender = self.sendQ.orderedRemove(0);
                    const valFromSender: T = sender.getDataAndSignal();
                    self.buf[l - 1] = valFromSender;
                }

                return val;
            }

            if (self.sendQ.items.len > 0) {
                defer self.mut.unlock();
                var sender: *Sender = self.sendQ.orderedRemove(0);
                const data: T = sender.getDataAndSignal();
                return data;
            }

            var receiver = Receiver{};

            receiver.mut.lock();
            defer receiver.mut.unlock();

            try self.recvQ.append(self.alloc, &receiver);
            self.mut.unlock();

            receiver.cond.wait(&receiver.mut);
            if (receiver.data) |data| {
                return data;
            } else {
                return ChanError.DataCorruption;
            }
        }
    };
}
