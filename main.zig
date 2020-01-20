pub const c = @cImport({
    @cInclude("SDL.h");
});
const assert = @import("std").debug.assert;

const SimWorld = @import("SimWorld.zig");
const Presentation = @import("Presentation.zig");

const SDL_WINDOWPOS_UNDEFINED = @bitCast(c_int, c.SDL_WINDOWPOS_UNDEFINED_MASK);

extern fn SDL_PollEvent(event: *c.SDL_Event) c_int;

inline fn SDL_RWclose(ctx: [*]c.SDL_RWops) c_int {
    return ctx[0].close.?(ctx);
}

pub fn main() !void {

    // Init
    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        c.SDL_Log(c"Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer c.SDL_Quit();

    // Window Creation
    const screen = c.SDL_CreateWindow(c"My Game Window", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 1200, 700, c.SDL_WINDOW_OPENGL) orelse
        {
        c.SDL_Log(c"Unable to create window: %s", c.SDL_GetError());
        return error.SDLInitializetionFailed;
    };
    defer c.SDL_DestroyWindow(screen);

    // Renderer
    const renderer = c.SDL_CreateRenderer(screen, -1, 0) orelse {
        c.SDL_Log(c"Unable to create renderer: %s", c.SDL_GetError());
        return error.SDLInitializetionFailed;
    };
    defer c.SDL_DestroyRenderer(renderer);

    Presentation.Initialize(renderer);

    MainGameLoop(screen, renderer);
}

pub fn MainGameLoop(screen: *c.SDL_Window, renderer: *c.SDL_Renderer) void {
    //TODO input handling
    var quit = false;
    while (!quit) {
        var event: c.SDL_Event = undefined;
        while (SDL_PollEvent(&event) != 0) {
            switch (event.@"type") {
                c.SDL_QUIT => {
                    quit = true;
                },
                else => {},
            }
        }

        //TODO update simulation
        SimWorld.WritableInstance().GameTick();

        //TODO update presentation
        Presentation.RenderFrame(renderer, SimWorld.Instance());

        c.SDL_Delay(17);
    }
}
