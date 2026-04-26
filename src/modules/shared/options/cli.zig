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
    \\--single-threaded     single threaded
);
count: usize = 2_000,
help: bool = false,
mode: Modes = .none,
single_threaded: bool = false,

pub fn create(gpa: std.mem.Allocator, args: std.process.Args, init: @This()) !@This() {
    var s = init;
    const res = clap.parse(clap.Help, &params, parsers, args, .{
        .diagnostic = &diag,
        .allocator = gpa,
        .assignment_separators = "= ",
    }) catch |err| {
        try diag.reportToFile(.failing, .stderr(), err);
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) s.help = true;
    if (res.args.count) |c| s.count = c;
    if (res.args.mode) |m| s.mode = m;
    if (res.args.@"single-threaded" != 0) s.single_threaded = true;

    return s;
}

pub fn printHelp(io: std.Io, file: std.Io.File) !void {
    return clap.helpToFile(io, file, clap.Help, &params, .{});
}
