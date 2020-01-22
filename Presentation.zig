const c = @import("c.zig");
const SimWorld = @import("SimWorld.zig").SimWorld;

pub fn Initialize(renderer: *c.SDL_Renderer) void {
    //pub fn Initialize() void {
    _ = c.SDL_SetRenderDrawColor(renderer, 255, 0, 0, 255);
}

pub fn RenderFrame(renderer: *c.SDL_Renderer, simWorld: *const SimWorld) void {
    //pub fn RenderFrame(simWorld: *const SimWorld) void {
    _ = c.SDL_RenderClear(renderer);

    c.SDL_RenderPresent(renderer); // End of Frame
}
