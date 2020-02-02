const c = @import("c.zig"); //can't use usingnamespace because of main() definition conflict
const std = @import("std");
const debug = std.debug;

const GameWorld = @import("game/GameWorld.zig");
const Presentation = @import("presentation/Presentation.zig");

const SDL_WINDOWPOS_UNDEFINED = @bitCast(c_int, c.SDL_WINDOWPOS_UNDEFINED_MASK);

extern fn SDL_PollEvent(event: *c.SDL_Event) c_int;

inline fn SDL_RWclose(ctx: [*]c.SDL_RWops) c_int {
    return ctx[0].close.?(ctx);
}

const InitError = error{
    GlewInit,
    SDLInit,
    OpenGLInit,
};

pub fn main() !void {
    // Setting pre-init attributes
    _ = c.SDL_GL_SetAttribute(@intToEnum(c.SDL_GLattr, c.SDL_GL_CONTEXT_MAJOR_VERSION), 4);
    _ = c.SDL_GL_SetAttribute(@intToEnum(c.SDL_GLattr, c.SDL_GL_CONTEXT_MINOR_VERSION), 6);

    // SDL init
    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        c.SDL_Log(c"Unable to initialize SDL: %s", c.SDL_GetError());
        return InitError.SDLInit;
    }
    defer c.SDL_Quit();

    // Window Creation
    const screen = c.SDL_CreateWindow(c"My Game Window", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 1200, 700, c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_RESIZABLE) orelse {
        c.SDL_Log(c"Unable to create window: %s", c.SDL_GetError());
        return InitError.SDLInit;
    };
    defer c.SDL_DestroyWindow(screen);

    // Renderer
    const renderer = c.SDL_CreateRenderer(screen, -1, 0) orelse {
        c.SDL_Log(c"Unable to create renderer: %s", c.SDL_GetError());
        return InitError.SDLInit;
    };
    defer c.SDL_DestroyRenderer(renderer);

    // Create context
    const glContext = c.SDL_GL_CreateContext(screen);
    if (@ptrToInt(glContext) == 0) {
        return InitError.SDLInit;
    }
    _ = c.SDL_GL_MakeCurrent(screen, glContext);

    // Glew init
    c.glewExperimental = c.GL_TRUE;
    var err: c.GLenum = c.glewInit();
    if (c.GLEW_OK != err) {
        return InitError.GlewInit;
    }
    const glVer: [*]const u8 = c.glGetString(c.GL_VERSION);
    if (@ptrToInt(glVer) != 0) {
        debug.warn("OpenGL version supported by this platform: {}\n", glVer[0..std.mem.len(u8, glVer)]);
    }
    // vsync on
    _ = c.SDL_GL_SetSwapInterval(1);

    Presentation.Initialize(renderer);
    GameWorld.Initialize();

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
        GameWorld.WritableInstance().GameTick();

        //TODO update presentation
        Presentation.RenderFrame(renderer, screen, GameWorld.Instance());

        c.SDL_Delay(17);
    }
}
