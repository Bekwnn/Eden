const c = @import("c.zig"); //can't use usingnamespace because of main() definition conflict
const std = @import("std");
const debug = std.debug;

const gameWorld = @import("game/GameWorld.zig");

const presentation = @import("presentation/Presentation.zig");
const sdlInit = @import("presentation/SDLInit.zig");

const imageFileUtil = @import("coreutil/ImageFileUtil.zig");

pub fn main() !void {
    try sdlInit.InitSDL();
    defer c.SDL_Quit();

    const window = try sdlInit.CreateWindow("Eden", 1280, 720);
    defer c.SDL_DestroyWindow(window);

    const renderer = try sdlInit.CreateRenderer(window);
    defer c.SDL_DestroyRenderer(renderer);

    // imgui setup TODO relocate TODO handle returns
    //_ = c.igCreateContext(null);
    //defer c.igDestroyContext(null);

    //_ = c.ImGui_ImplSDL2_InitForOpenGL(window, glContext);
    //_ = c.ImGui_ImplOpenGL3_Init(null);

    //stb image wip test
    const testImagePath = "test-assets\\test.png";
    if (imageFileUtil.LoadImage(testImagePath)) |*image| {
        defer image.FreeImage();
        debug.warn("Successfully loaded test image {s}\n", .{testImagePath});
        // where you would use the image...
    } else |err| {
        debug.warn("Failed to load test image {s}, {}\n", .{ testImagePath, err });
    }

    presentation.Initialize(renderer);
    gameWorld.Initialize();

    try MainGameLoop(window, renderer);
}

pub fn MainGameLoop(window: *c.SDL_Window, renderer: *c.SDL_Renderer) !void {
    //TODO input handling
    var quit = false;
    while (!quit) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            //_ = c.ImGui_ImplSDL2_ProcessEvent(&event);
            switch (event.@"type") {
                c.SDL_QUIT => {
                    quit = true;
                },
                else => {},
            }
        }

        gameWorld.WritableInstance().Update(1.0 / 60.0);
        gameWorld.WritableInstance().FixedUpdate();

        try presentation.RenderFrame(renderer, window, gameWorld.Instance());

        c.SDL_Delay(17);
    }
}
