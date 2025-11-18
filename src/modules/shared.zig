const buildin = @import("builtin");
pub const Loop = @import("shared/loop/loop.zig");
pub const Raycast = @import("shared/raycast/raycast.zig");
pub const Jgk = @import("shared/jgk/jgk.zig");
pub const Sap = @import("shared/sap/sap.zig");
pub const Options = if (buildin.target.os.tag == .emscripten) @import("shared/options/mock.zig") else @import("shared/options/cli.zig");
