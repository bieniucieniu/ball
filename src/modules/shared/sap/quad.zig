pub const Axis = enum { x, y, horizontal, vertical };

min: f32,
max: f32,
pub fn init(min: f32, max: f32) @This() {
    return .{ min, max };
}
