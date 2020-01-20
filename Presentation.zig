const c = @cImport({
    @cInclude("SDL.h");
});
const SimWorld = @import("SimWorld.zig").SimWorld;

pub fn Initialize(renderer: *c.SDL_Renderer) void {
    c.SDL_SetRenderDrawColor(renderer, 255, 0, 0, 255);
}

pub fn RenderFrame(renderer: *c.SDL_Renderer, simWorld: *const SimWorld) void {
    c.SDL_RenderClear(renderer);
}
