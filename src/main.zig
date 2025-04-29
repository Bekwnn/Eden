const c = @import("c.zig");
const std = @import("std");
const debug = std.debug;

const gameWorld = @import("game/GameWorld.zig");

const presentation = @import("presentation/Presentation.zig");
const RenderContext = @import("presentation/RenderContext.zig").RenderContext;
const imgui = @import("presentation/ImGui.zig");
const sdlInit = @import("presentation/SDLInit.zig");

const imageFileUtil = @import("coreutil/ImageFileUtil.zig");

pub fn main() !void {
    try sdlInit.InitSDL();
    defer c.SDL_Quit();

    const window = try sdlInit.CreateWindow("Eden", 1280, 720);
    defer c.SDL_DestroyWindow(window);

    const renderer = try sdlInit.CreateRenderer(window);
    defer c.SDL_DestroyRenderer(renderer);

    try presentation.Initialize(window, "Eden", 0);
    defer presentation.Shutdown();

    //stb image wip test
    const testImagePath = "test-assets\\test.png";
    var image: ?imageFileUtil.ImageFile = imageFileUtil.LoadImage(testImagePath) catch null;
    if (image != null) {
        debug.print("Successfully loaded test image {s}\n", .{testImagePath});
        // where you would use the image...
        image.?.FreeImage();
    } else {
        debug.print("Failed to load test image {s}\n", .{testImagePath});
    }

    //presentation.Initialize(renderer);
    gameWorld.Initialize();

    try MainGameLoop(window);

    // teardown
}

pub fn MainGameLoop(window: *c.SDL_Window) !void {
    //TODO input handling
    var quit = false;
    var stop_rendering = false;
    while (!quit) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            //_ = c.ImGui_ImplSDL2_ProcessEvent(&event);
            switch (event.type) {
                c.SDL_QUIT => {
                    quit = true;
                },
                c.SDL_WINDOWEVENT => {
                    if (event.window.event == c.SDL_WINDOWEVENT_RESIZED and
                        event.window.windowID == c.SDL_GetWindowID(window))
                    {
                        try presentation.OnWindowResized(window);
                    }
                    if (event.window.event == c.SDL_WINDOWEVENT_MINIMIZED) {
                        stop_rendering = true;
                    }
                    if (event.window.event == c.SDL_WINDOWEVENT_RESTORED) {
                        stop_rendering = false;
                    }
                },
                else => {},
            }
        }

        gameWorld.WritableInstance().Update(1.0 / 60.0);
        gameWorld.WritableInstance().FixedUpdate();

        if (!stop_rendering) {
            //TODO move out imgui code to somewhere within presentation probably
            c.ImGui_ImplVulkan_NewFrame();
            c.ImGui_ImplSDL2_NewFrame();

            c.igNewFrame();
            c.igShowDemoWindow(null);
            c.igRender();

            try presentation.RenderFrame();
        }

        c.SDL_Delay(17);
    }
}
