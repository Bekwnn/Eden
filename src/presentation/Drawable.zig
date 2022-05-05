// The base interface for a renderable object.
// Is this how we want to handle drawing things?

//const Camera = @import("Camera.zig").Camera;
//
//pub const Drawable = struct {
//    drawFn: fn (*Drawable, *const Camera) void,
//};
//
//const PointState = struct {
//    x: f32,
//    y: f32,
//    z: f32,
//};
//
//pub const PointDrawable = struct {
//    drawable: Drawable = Drawable{ .drawFn = debug1 },
//    state: PointState = PointState{ .x = 0.0, .y = 0.0, .z = 0.0 },
//
//    fn debug1(drawable: *const Drawable) void {
//        const self = @fieldParentPtr(PointDrawable, "drawable", drawable);
//        std.debug.warn("{{{}, {}, {}}}\n", .{
//            self.state.x,
//            self.state.y,
//            self.state.z,
//        });
//    }
//};
//
//pub fn fakemain() void {
//    var pointActor = PointDrawable{};
//    var sceneDrawableActorsList = [_]*Drawable{&pointActor.drawable};
//    for (sceneDrawableActorsList) |actor| {
//        actor.drawFn(actor);
//    }
//}
