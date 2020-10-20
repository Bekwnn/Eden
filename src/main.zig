const c = @import("c.zig"); //can't use usingnamespace because of main() definition conflict
const std = @import("std");
const debug = std.debug;
const Vec2 = @import("math/Vec2.zig").Vec2;

const gameWorld = @import("game/GameWorld.zig");
const presentation = @import("presentation/Presentation.zig");
const assimp = @import("presentation/AssImpInterface.zig");

//TODO move test and delete
const TransformComp = @import("game/ComponentData/TransformComp.zig").TransformComp;

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

fn ReportSDLError(message: [:0]const u8) void {
    const errStr = c.SDL_GetError();
    debug.warn("{}: {}", .{message, errStr[0..std.mem.len(errStr)]});
}


pub fn main() !void {
    // Setting pre-init attributes
    _ = c.SDL_GL_SetAttribute(@intToEnum(c.SDL_GLattr, c.SDL_GL_CONTEXT_MAJOR_VERSION), 4);
    _ = c.SDL_GL_SetAttribute(@intToEnum(c.SDL_GLattr, c.SDL_GL_CONTEXT_MINOR_VERSION), 6);

    // SDL init
    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        ReportSDLError("Unable to initialize SDL");
        return InitError.SDLInit;
    }
    defer c.SDL_Quit();

    // Window Creation
    const screen = c.SDL_CreateWindow("My Game Window", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 1200, 700, c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_RESIZABLE) orelse {
        ReportSDLError("Unable to create window");
        return InitError.SDLInit;
    };
    defer c.SDL_DestroyWindow(screen);

    // Renderer
    const renderer = c.SDL_CreateRenderer(screen, -1, 0) orelse {
        ReportSDLError("Unable to create renderer");
        return InitError.SDLInit;
    };
    defer c.SDL_DestroyRenderer(renderer);

    // Create context
    const glContext = c.SDL_GL_CreateContext(screen);
    if (@ptrToInt(glContext) == 0) {
        ReportSDLError("Unable to create GLContext");
        return InitError.SDLInit;
    }

    _ = c.SDL_GL_MakeCurrent(screen, glContext);

    // Glew init
    c.glewExperimental = c.GL_TRUE;
    var glewInitErr: c.GLenum = c.glewInit();
    if (c.GLEW_OK != glewInitErr) {
        debug.warn("GlewInit failed", .{});
        return InitError.GlewInit;
    }
    const glVer: [*:0]const u8 = c.glGetString(c.GL_VERSION);
    if (@ptrToInt(glVer) != 0) {
        debug.warn("OpenGL version supported by this platform: {}\n", .{glVer[0..std.mem.len(glVer)]});
    }
    // vsync on
    _ = c.SDL_GL_SetSwapInterval(1);

    // imgui setup TODO relocate TODO handle returns
    _ = c.igCreateContext(null);
    defer c.igDestroyContext(null);

    _ = c.ImGui_ImplSDL2_InitForOpenGL(screen, glContext);
    _ = c.ImGui_ImplOpenGL3_Init(null);

    _ = assimp.ImportMesh("F:/Dev Demos and Content/Zig/Eden/test-assets/test.fbx") catch |meshErr|
    {
        debug.warn("Error importing mesh: {}\n", .{meshErr});
    };

    presentation.Initialize(renderer);
    gameWorld.Initialize();

    MainGameLoop(screen, renderer);
}

pub fn MainGameLoop(screen: *c.SDL_Window, renderer: *c.SDL_Renderer) void {
    //TODO input handling
    var quit = false;
    while (!quit) {
        var event: c.SDL_Event = undefined;
        while (SDL_PollEvent(&event) != 0) {
            _ = c.ImGui_ImplSDL2_ProcessEvent(&event);
            switch (event.@"type") {
                c.SDL_QUIT => {
                    quit = true;
                },
                else => {},
            }
        }

        gameWorld.WritableInstance().Update(1.0 / 60.0);
        gameWorld.WritableInstance().FixedUpdate();

        presentation.RenderFrame(renderer, screen, gameWorld.Instance());

        c.SDL_Delay(17);
    }
}

test "create entity" {
    //TODO
    debug.warn("\n", .{});
    const newEntity = gameWorld.WritableInstance().CreateEntity();
    debug.warn("newEntityId: {}\n", .{newEntity.m_eid});
    const newCompID = gameWorld.WritableInstance().m_componentManager.AddComponent(TransformComp, newEntity.m_eid);
    debug.warn("newTransformCompID: {}\n", .{newCompID});
    debug.warn("{}\n", .{gameWorld.WritableInstance().m_componentManager.m_transformCompData.m_compData.len});
    if (gameWorld.WritableInstance().m_componentManager.GetComponent(TransformComp, newCompID)) |compData| {
        debug.warn("scale: {}, {}, {}\n", .{ compData.scale.x, compData.scale.y, compData.scale.z });
    }
    if (gameWorld.WritableInstance().m_componentManager.GetComponentOwnerId(TransformComp, newCompID)) |ownerId| {
        debug.warn("ownerId: {}\n", .{ownerId});
    }
}
