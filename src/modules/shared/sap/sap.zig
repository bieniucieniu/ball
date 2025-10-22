const rl = @import("raylib");
const std = @import("std");
pub const Quad = @import("quad.zig");

pub fn TagedSap(T: type) type {
    return struct {
        const Q = Quad.TagedQuad(T);

        alloc: std.mem.Allocator,
        quads: []Q,
        all_pairs: std.ArrayList([2]T),
        active_list: std.ArrayList(?Q),

        pub fn init(alloc: std.mem.Allocator, init_size: usize) !@This() {
            return .{
                .alloc = alloc,
                .active_list = try .initCapacity(alloc, init_size),
                .all_pairs = try .initCapacity(alloc, init_size),
                .quads = try alloc.alloc(Q, init_size),
            };
        }
        pub fn deinit(s: *@This()) void {
            s.active_list.deinit(s.alloc);
            s.all_pairs.deinit(s.alloc);
            s.alloc.free(s.quads);
        }
        pub fn copyQuads(s: *@This(), quads: []const Q) !void {
            if (quads.len != s.quads.len) {
                s.alloc.free(s.quads);
                s.quads = try s.alloc.alloc(Q, quads.len);
            }
            for (quads, 0..) |*q, i| s.quads[i] = q.*;
        }
        pub fn setQuadsAsSlice(s: *@This(), size: usize) ![]Q {
            if (size != s.quads.len) {
                s.alloc.free(s.quads);
                s.quads = try s.alloc.alloc(Q, size);
            }
            return s.quads;
        }
        pub fn reset(s: *@This(), capacity: usize) !void {
            s.active_list.clearRetainingCapacity();
            try s.active_list.ensureTotalCapacity(s.alloc, capacity);
            s.all_pairs.clearRetainingCapacity();
            try s.all_pairs.ensureTotalCapacity(s.alloc, capacity);
        }

        pub fn runWith(s: *@This(), quads: []const Q) ![]const Q {
            try s.copyQuads(quads);
            std.mem.sort(Q, s.quads, {}, Q.minAsc);
            return s.run();
        }
        pub fn getPairs(s: *@This()) ![][2]T {
            try s.reset(s.quads.len);

            for (s.quads) |q| {
                var j: usize = 0;
                inner: while (j < s.active_list.items.len) : (j += 1) {
                    const a = s.active_list.items[j] orelse continue :inner;
                    //std.debug.print("comparing:\n\t {} and {}\n", .{ q, a });
                    if (q.min > a.max) {
                        //std.debug.print("poping:\n\t{?}\n", .{s.active_list.items[j]});
                        s.active_list.items[j] = null;
                    } else {
                        //std.debug.print("reported pair:\n\t {} and {}\n", .{ q, a });
                        try s.all_pairs.append(s.alloc, .{ q.tag, a.tag });
                    }
                }
                //std.debug.print("added to activeList:\n\t{}\n", .{q});
                try s.active_list.append(s.alloc, q);
            }
            return s.all_pairs.items;
        }
    };
}
