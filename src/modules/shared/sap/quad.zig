pub const Axis = enum { x, y, horizontal, vertical };

fn TagedQuad(Tag: type) type {
    return struct {
        min: f32,
        max: f32,
        tag: Tag,
        pub fn init(min: f32, max: f32) @This() {
            return .{ min, max };
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
