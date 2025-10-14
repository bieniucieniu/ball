const rl = @import("raylib");

pub fn raysIntersection(as: rl.Vector2, ad: rl.Vector2, bs: rl.Vector2, bd: rl.Vector2) ?rl.Vector2 {
    if (as.equals(bs) != 0) return as;
    const det = bd.x * ad.y - bd.y * ad.x;
    if (det != 0) {
        const dx = bs.x - as.x;
        const dy = bs.y - as.y;
        const u = (dy * bd.x - dx * bd.y) / det;
        const v = (dy * ad.x - dx * ad.y) / det;
        if (u >= 0 and u <= 1 and v >= 0 and v <= 1) {
            return as.add(ad).scale(u);
        }
    }
    return null;
}
