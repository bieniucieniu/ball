const std = @import("std");
const clap = @import("clap");

const parsers = .{
    .uint = clap.parsers.int(usize, 10),
    .str = clap.parsers.string,
};

var diag: clap.Diagnostic = .{};
const params = clap.parseParamsComptime(
    \\-c, --count <uint>    count 
    \\-h, --help            help
);

count: usize = 2_000,
help: bool = false,

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

    return s;
}

pub fn printHelp(file: std.fs.File) !void {
    return clap.helpToFile(file, clap.Help, &params, .{});
}
