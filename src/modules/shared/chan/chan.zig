const std = @import("std");

const ChanError = error{
    Closed,
    Locked,
    Empty,
    OutOfMemory,
    NotImplemented,
    DataCorruption,
};

pub fn Chan(comptime T: type) type {
    return BufferedChan(T, 0);
}

pub fn BufferedChan(comptime T: type, comptime bufSize: u8) type {
    return struct {
        alloc: std.mem.Allocator,
        impl: BufferedChanUnmanaged(T, bufSize) = .{},

        pub fn init(alloc: std.mem.Allocator) @This() {
            return .{
                .alloc = alloc,
            };
        }

        pub fn deinit(self: *@This()) void {
            self.impl.deinit(self.alloc);
        }

        pub fn close(self: *@This()) void {
            self.impl.close();
        }

        pub fn capacity(self: *@This()) u8 {
            return self.impl.capacity();
        }

        pub fn debugBuf(self: *@This()) void {
            self.impl.debugBuf();
        }

        pub fn len(self: *@This()) u8 {
            return self.impl.len();
        }

        pub fn send(self: *@This(), data: T) ChanError!void {
            return self.impl.send(self.alloc, data);
        }

        pub fn recv(self: *@This()) ChanError!T {
            return self.impl.recv(self.alloc);
        }
    };
}
pub fn BufferedChanUnmanaged(comptime T: type, comptime bufSize: u8) type {
    return struct {
        pub const bufType = [bufSize]?T;
        buf: bufType = [_]?T{null} ** bufSize,
        closed: bool = false,
        mut: std.Thread.Mutex = .{},
        recvQ: std.ArrayListUnmanaged(*Receiver) = .{},
        sendQ: std.ArrayListUnmanaged(*Sender) = .{},

        pub const Receiver = struct {
            mut: std.Thread.Mutex = std.Thread.Mutex{},
            cond: std.Thread.Condition = std.Thread.Condition{},
            data: ?T = null,

            fn putDataAndSignal(self: *@This(), data: T) void {
                defer self.cond.signal();
                self.data = data;
            }
        };

        pub const Sender = struct {
            mut: std.Thread.Mutex = std.Thread.Mutex{},
            cond: std.Thread.Condition = std.Thread.Condition{},
            data: T,

            fn getDataAndSignal(self: *@This()) T {
                defer self.cond.signal();
                return self.data;
            }
        };

        pub fn deinit(self: *@This(), alloc: std.mem.Allocator) void {
            self.recvQ.deinit(alloc);
            self.sendQ.deinit(alloc);
        }

        pub fn close(self: *@This()) void {
            self.closed = true;
        }

        pub fn capacity(self: *@This()) u8 {
            return self.buf.len;
        }

        pub fn debugBuf(self: *@This()) void {
            std.debug.print("{d} Buffer debug\n", .{std.time.milliTimestamp()});
            for (self.buf, 0..) |item, i| {
                if (item) |unwrapped| {
                    std.debug.print("[{d}] = {d}\n", .{ i, unwrapped });
                }
            }
        }

        pub fn len(self: *@This()) u8 {
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

        pub fn send(self: *@This(), alloc: std.mem.Allocator, data: T) ChanError!void {
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

            try self.sendQ.append(alloc, &sender);
            self.mut.unlock();
            sender.cond.wait(&sender.mut);
            return;
        }

        pub fn recvNoBlock(self: *@This()) ChanError!T {
            if (self.closed) return ChanError.Closed;
            if (!self.mut.tryLock()) return ChanError.Locked;
            errdefer self.mut.unlock();

            const l = self.len();
            if (l > 0 and bufSize > 0) {
                defer self.mut.unlock();
                const val = self.buf[0] orelse return ChanError.DataCorruption;

                if (l > 1) {
                    for (self.buf[1..l], 0..l - 1) |item, i|
                        self.buf[i] = item;
                }
                self.buf[l - 1] = null;

                if (self.sendQ.items.len > 0) {
                    var sender: *Sender = self.sendQ.orderedRemove(0);
                    const valFromSender: T = sender.getDataAndSignal();
                    self.buf[l - 1] = valFromSender;
                }

                return val;
            }

            return ChanError.Empty;
        }

        pub fn recv(self: *@This(), alloc: std.mem.Allocator) ChanError!T {
            if (self.closed) return ChanError.Closed;
            self.mut.lock();
            errdefer self.mut.unlock();

            const l = self.len();
            if (l > 0 and bufSize > 0) {
                defer self.mut.unlock();
                const val = self.buf[0] orelse return ChanError.DataCorruption;

                if (l > 1) {
                    for (self.buf[1..l], 0..l - 1) |item, i|
                        self.buf[i] = item;
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

            try self.recvQ.append(alloc, &receiver);
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
