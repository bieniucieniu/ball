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
const message_queue = @import("shared/message-queue/message-queue.zig");
pub const MessageQueue = message_queue.MessageQueue;
pub const MessageQueueSendError = message_queue.MessageQueueSendError;
pub const MessageQueueOptions = message_queue.Options;
