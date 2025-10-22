pub const Axis = enum { x, y, horizontal, vertical };

pub fn TagedQuad(T: type) type {
    return struct {
        min: f32,
        max: f32,
        tag: T,
        pub fn init(min: f32, max: f32, tag: T) @This() {
            return .{ .min = min, .max = max, .tag = tag };
        }
        pub fn minAsc(_: void, a: @This(), b: @This()) bool {
            return a.min < b.min;
        }
    };
}

min: f32,
max: f32,
pub fn init(min: f32, max: f32) @This() {
    return .{ min, max };
}
