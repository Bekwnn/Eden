const c = @import("c.zig").cLib;
const std = @import("std");
const debug = std.debug;
const time = std.time;
const Timestamp = std.Io.Timestamp;

const gameWorld = @import("game/GameWorld.zig");

const presentation = @import("presentation/Presentation.zig");
const editor = @import("presentation/editor/Editor.zig");
const RenderContext = @import("presentation/RenderContext.zig").RenderContext;
const sdlInit = @import("presentation/SDLInit.zig");

const imageFileUtil = @import("coreutil/ImageFileUtil.zig");

pub var mainInit: std.process.Init = undefined;

pub fn main(init: std.process.Init) !void {
    mainInit = init;

    try sdlInit.InitSDL();
    defer c.SDL_Quit();

    const window = try sdlInit.CreateWindow("Eden", 1280, 720);
    defer c.SDL_DestroyWindow(window);

    const renderer = try sdlInit.CreateRenderer(window);
    defer c.SDL_DestroyRenderer(renderer);

    try presentation.Initialize(init.gpa, init.io, window, "Eden", 0);
    defer presentation.Shutdown();

    //stb image wip test
    const testImagePath = "test-assets\\test.png";
    var image: ?imageFileUtil.ImageFile = imageFileUtil.LoadImage(init.gpa, init.io, testImagePath) catch null;
    if (image != null) {
        debug.print("Successfully loaded test image {s}\n", .{testImagePath});
        // where you would use the image...
        image.?.FreeImage();
    } else {
        debug.print("Failed to load test image {s}\n", .{testImagePath});
    }

    gameWorld.Initialize(init.gpa);

    try editor.Initialize(init.gpa, window);
    defer editor.Deinit();

    frameTimestamp = std.Io.Timestamp.now(init.io, std.Io.Clock.real);
    try MainGameLoop(init.gpa, init.io, window);

    // teardown
}

// if we hit min FPS, we clamp the deltaT to minFPS and let the game run in slow-mo
// if we hit max FPS, we clamp the deltaT to maxFPS and sleep for the remaining time left
const minFPS = 10.0;
const maxDeltaNs: i96 = @trunc(@as(f32, @floatFromInt(time.ns_per_s)) / minFPS);
const maxFPS = 240.0;
const minDeltaNs: i96 = @trunc(@as(f32, @floatFromInt(time.ns_per_s)) / maxFPS);
var frameTimestamp: std.Io.Timestamp = undefined;

pub fn MainGameLoop(allocator: std.mem.Allocator, io: std.Io, window: *c.SDL_Window) !void {
    var quit = false;
    var stop_rendering = false;
    while (!quit) {
        // Update frame timer
        const rawDelta = frameTimestamp.untilNow(io, std.Io.Clock.real);
        const clampedDeltaNs = std.math.clamp(rawDelta.nanoseconds, minDeltaNs, maxDeltaNs);
        if (rawDelta.nanoseconds < minDeltaNs) {
            // sleep if exceeding max fps
            try std.Io.sleep(
                io,
                std.Io.Duration{ .nanoseconds = minDeltaNs - rawDelta.nanoseconds },
                std.Io.Clock.real,
            );
        }
        const deltaT: f32 = @as(f32, @floatFromInt(clampedDeltaNs)) / @as(f32, @floatFromInt(time.ns_per_s));

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
                        try presentation.OnWindowResized(allocator, window);
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

            try editor.UpdateCameraMovement(deltaT);

            c.igNewFrame();
            try editor.Draw();
            c.igRender(); // does not actually draw, drawing happens in RenderFrame()
            //
            try presentation.RenderFrame(allocator, deltaT);
        }
    }
}
