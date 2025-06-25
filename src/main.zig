const c = @import("c.zig");
const std = @import("std");
const debug = std.debug;
const time = std.time;

const gameWorld = @import("game/GameWorld.zig");

const presentation = @import("presentation/Presentation.zig");
const RenderContext = @import("presentation/RenderContext.zig").RenderContext;
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

    frameTimer = try time.Timer.start();
    try MainGameLoop(window);

    // teardown
}

// if we hit min FPS, we clamp the deltaT to minFPS and let the game run in slow-mo
// if we hit max FPS, we clamp the deltaT to maxFPS and sleep for the remaining time left
const minFPS = 10.0;
const maxDeltaNs: u64 = @intFromFloat(@as(f32, @floatFromInt(time.ns_per_s)) / minFPS);
const maxFPS = 240.0;
const minDeltaNs: u64 = @intFromFloat(@as(f32, @floatFromInt(time.ns_per_s)) / maxFPS);
var frameTimer: time.Timer = undefined;

pub fn MainGameLoop(window: *c.SDL_Window) !void {
    var quit = false;
    var stop_rendering = false;
    while (!quit) {
        // Update frame timer
        const rawDeltaNs = frameTimer.lap();
        const clampedDeltaNs = std.math.clamp(rawDeltaNs, minDeltaNs, maxDeltaNs);
        if (rawDeltaNs < minDeltaNs) {
            // sleep if exceeding max fps
            time.sleep(minDeltaNs - rawDeltaNs);
        }
        const deltaT = @as(f32, @floatFromInt(clampedDeltaNs)) / @as(f32, @floatFromInt(time.ns_per_s));

        //Input handling and window events
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
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

            _ = c.ImGui_ImplSDL2_ProcessEvent(&event);
        }

        gameWorld.WritableInstance().Update(deltaT);
        gameWorld.WritableInstance().FixedUpdate();

        if (!stop_rendering) {
            //TODO move out imgui code to somewhere within presentation probably
            c.ImGui_ImplVulkan_NewFrame();
            c.ImGui_ImplSDL2_NewFrame();

            c.igNewFrame();
            try presentation.ImguiFrame(deltaT, rawDeltaNs);
            c.igRender(); // does not actually draw, drawing happens in RenderFrame()

            try presentation.RenderFrame(deltaT);
        }
    }
}
