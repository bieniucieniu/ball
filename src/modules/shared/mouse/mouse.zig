const rl = @import("raylib");

pub inline fn getMouseX(mouse: rl.Vector2, boundry: rl.Rectangle) f32 {
    return if (mouse.x <= boundry.x)
        boundry.x
    else if (mouse.x >= boundry.x + boundry.width)
        boundry.x + boundry.width
    else
        mouse.x;
}
pub inline fn getMouseY(mouse: rl.Vector2, boundry: rl.Rectangle) f32 {
    return if (mouse.y <= boundry.y)
        boundry.y
    else if (mouse.y >= boundry.y + boundry.height)
        boundry.y + boundry.height
    else
        mouse.y;
}

pub fn getMouse(boundry: rl.Rectangle) rl.Vector2 {
    const mouse = rl.getMousePosition();
    return rl.Vector2.init(
        getMouseX(mouse, boundry),
        getMouseY(mouse, boundry),
    );
}
