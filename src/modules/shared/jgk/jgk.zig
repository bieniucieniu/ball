/// zig rewrite of https://github.com/kroitor/gjk.c/blob/master/gjk.c
/// using raylib.zig Vector2
const rl = @import("raylib");
pub fn perpendicular(v: rl.Vector2) rl.Vector2 {
    return .{
        .x = v.y,
        .y = -v.x,
    };
}
pub fn tripleProductRL(a: rl.Vector2, b: rl.Vector2, c: rl.Vector2) rl.Vector2 {
    // var r: rl.Vector2 = .init(0, 0);
    //
    // const ac = a.dotProduct(c); // a.x * c.x + a.y * c.y; // perform a.dot(c)
    // const bc = b.dotProduct(c); // b.x * c.x + b.y * c.y; // perform b.dot(c)

    // perform b * a.dot(c) - a * b.dot(c)
    const bac = b.multiply(a.dotProduct(c));
    const abc = a.multiply(b.dotProduct(c));
    return bac.subtract(abc);
    // r.x = b.x * ac - a.x * bc;
    // r.y = b.y * ac - a.y * bc;
    // return r;
}

pub fn tripleProduct(a: rl.Vector2, b: rl.Vector2, c: rl.Vector2) rl.Vector2 {
    var r: rl.Vector2 = .init(0, 0);

    const ac = a.x * c.x + a.y * c.y;
    const bc = b.x * c.x + b.y * c.y;

    r.x = b.x * ac - a.x * bc;
    r.y = b.y * ac - a.y * bc;

    return r;
}
pub fn averagePoint(vertices: []const rl.Vector2) rl.Vector2 {
    const avg: rl.Vector2 = .init(0, 0);
    for (vertices) |p| {
        avg.x += p.x;
        avg.y += p.y;
    }
    avg.x /= vertices.len;
    avg.y /= vertices.len;
    return avg;
}

pub fn indexOfFurthestPoint(vertices: []const rl.Vector2, d: rl.Vector2) usize {
    var max = d.dotProduct(vertices[0]);
    var idx: usize = 0;
    for (vertices, 0..) |p, i| {
        const product = d.dotProduct(p);
        if (product > max) {
            max = product;
            idx = i;
        }
    }
    return idx;
}
pub fn furthestPoint(vertices: []const rl.Vector2, d: rl.Vector2) rl.Vector2 {
    return vertices[indexOfFurthestPoint(vertices, d)];
}

pub fn support(
    vertices1: []const rl.Vector2,
    vertices2: []const rl.Vector2,
    d: rl.Vector2,
) rl.Vector2 {

    // get furthest point of first body along an arbitrary direction
    const i = furthestPoint(vertices1, d);

    // get furthest point of second body along the opposite direction
    const j = furthestPoint(vertices2, d.negate());

    // subtract (Minkowski sum) the two points to see if bodies 'overlap'
    return i.subtract(j);
}

threadlocal var iter_count: usize = 0;

pub fn gjk(vertices1: []const rl.Vector2, vertices2: []const rl.Vector2) bool {
    var index: usize = 0; // index of current vertex of simplex
    //vec2 a, b, c, d, ao, ab, ac, abperp, acperp, simplex[3];
    var a: rl.Vector2 = undefined;
    var b: rl.Vector2 = undefined;
    var c: rl.Vector2 = undefined;
    var d: rl.Vector2 = undefined;
    var ao: rl.Vector2 = undefined;
    var ab: rl.Vector2 = undefined;
    var ac: rl.Vector2 = undefined;
    var simplex: [3]rl.Vector2 = undefined;
    const position1 = averagePoint(vertices1); // not a CoG but
    const position2 = averagePoint(vertices2); // it's ok for GJK )

    // initial direction from the center of 1st body to the center of 2nd body
    d = position1.subtract(position2);

    // if initial direction is zero – set it to any arbitrary axis (we choose X)
    if ((d.x == 0) and (d.y == 0))
        d.x = 1;

    // set the first support as initial point of the new simplex
    simplex[0] = support(vertices1, vertices2, d);
    a = simplex[0];

    if (a.dotProduct(d) <= 0)
        return 0; // no collision

    d = a.negate(); // The next search direction is always towards the origin, so the next search direction is negate(a)

    while (1) {
        iter_count += 1;
        index += 1;
        a = simplex[index];
        simplex[0] = support(vertices1, vertices2, d);

        if (a.dotProduct(d) <= 0)
            return 0; // no collision

        ao = a.negate(); // from point A to Origin is just negative A

        // simplex has 2 points (a line segment, not a triangle yet)
        if (index < 2) {
            b = simplex[0];
            ab = b.subtract(a); // from point A to B
            d = tripleProduct(ab, ao, ab); // normal to AB towards Origin
            if (d.lengthSqr() == 0)
                d = perpendicular(ab);
            continue; // skip to next iteration
        }

        b = simplex[1];
        c = simplex[0];
        ab = a.subtract(b); // from point A to B
        ac = a.subtract(c); // from point A to C

        var acperp = tripleProduct(ab, ac, ac);

        if (acperp.dotProduct(ao) >= 0) {
            d = acperp; // new direction is normal to AC towards Origin

        } else {
            const abperp = tripleProduct(ac, ab, ab);

            if (abperp.dotProduct(ao) < 0)
                return 1; // collision

            simplex[0] = simplex[1]; // swap first element (point C)

            d = abperp; // new direction is normal to AB towards Origin
        }

        simplex[1] = simplex[2]; // swap element in the middle (point B)
        index -= 1;
    }

    return 0;
}
