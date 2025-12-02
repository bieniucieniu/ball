const buildin = @import("builtin");
pub const Loop = @import("shared/loop/loop.zig");
pub const Raycast = @import("shared/raycast/raycast.zig");
pub const Jgk = @import("shared/jgk/jgk.zig");
pub const Sap = @import("shared/sap/sap.zig");
pub const Options =
    switch (buildin.target.os.tag) {
        .emscripten, .wasi => @import("shared/options/mock.zig"),
        else => @import("shared/options/cli.zig"),
    };
const chan = @import("shared/chan/chan.zig");
pub const Chan = chan.Chan;
pub const BufferedChan = chan.BufferedChan;
pub const BufferedChanUnmanaged = chan.BufferedChanUnmanaged;
const queue = @import("shared/queue/event-queue.zig");
pub const Queue = queue.EventQueue;
pub const QueueSendError = queue.EventQueueSendError;
pub const QueueOptions = queue.Options;
pub const OverflowPolicy = queue.OverflowPolicy;
pub const mouse = @import("shared/mouse/mouse.zig");
