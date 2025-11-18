const std = @import("std");
const clap = @import("clap");
const Modes = @import("shared.zig").Modes;

pub const CLI = true;

const parsers = .{
    .uint = clap.parsers.int(usize, 10),
    .str = clap.parsers.string,
    .mode = clap.parsers.enumeration(Modes),
};

var diag: clap.Diagnostic = .{};
const params = clap.parseParamsComptime(
    \\-c, --count <uint>    count 
    \\-h, --help            help
    \\-m, --mode <mode>     mode
);

count: usize = 2_000,
help: bool = false,
mode: Modes = .none,

pub fn create(allocator: std.mem.Allocator, defaults: @This()) !@This() {
    var s: @This() = defaults;
    const res = clap.parse(clap.Help, &params, parsers, .{
        .diagnostic = &diag,
        .allocator = allocator,
        .assignment_separators = "= ",
    }) catch |err| {
        try diag.reportToFile(.stderr(), err);
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) s.help = true;
    if (res.args.count) |c| s.count = c;
    if (res.args.mode) |m| s.mode = m;

    return s;
}

pub fn printHelp(file: std.fs.File) !void {
    return clap.helpToFile(file, clap.Help, &params, .{});
}
