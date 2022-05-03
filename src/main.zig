const c = @import("c.zig"); //can't use usingnamespace because of main() definition conflict
const std = @import("std");
const debug = std.debug;

const gameWorld = @import("game/GameWorld.zig");

const presentation = @import("presentation/Presentation.zig");
const imgui = @import("presentation/ImGui.zig");
const sdlInit = @import("presentation/SDLInit.zig");
const vk = @import("presentation/VulkanInit.zig");

const imageFileUtil = @import("coreutil/ImageFileUtil.zig");

pub fn main() !void {
    try sdlInit.InitSDL();
    defer c.SDL_Quit();

    const window = try sdlInit.CreateWindow("Eden", 1280, 720);
    defer c.SDL_DestroyWindow(window);

    const renderer = try sdlInit.CreateRenderer(window);
    defer c.SDL_DestroyRenderer(renderer);

    presentation.Initialize(); //TODO temp, delete should happen later
    try vk.VulkanInit(window);
    defer {
        //TODO handle
        _ = c.vkDeviceWaitIdle(vk.logicalDevice);
        vk.VulkanCleanup();
    }

    // imgui setup
    //try imgui.InitImgui(window);
    //defer imgui.CleanupImgui();

    //stb image wip test
    const testImagePath = "test-assets\\test.png";
    if (imageFileUtil.LoadImage(testImagePath)) |*image| {
        defer image.FreeImage();
        debug.print("Successfully loaded test image {s}\n", .{testImagePath});
        // where you would use the image...
    } else |err| {
        debug.print("Failed to load test image {s}, {}\n", .{ testImagePath, err });
    }

    //presentation.Initialize(renderer);
    gameWorld.Initialize();

    try MainGameLoop(window);
}

pub fn MainGameLoop(window: *c.SDL_Window) !void {
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
                c.SDL_WINDOWEVENT => {
                    if (event.window.event == c.SDL_WINDOWEVENT_RESIZED and
                        event.window.windowID == c.SDL_GetWindowID(window))
                    {
                        try presentation.OnWindowResized(window);
                    }
                },
                else => {},
            }
        }

        gameWorld.WritableInstance().Update(1.0 / 60.0);
        gameWorld.WritableInstance().FixedUpdate();

        try presentation.RenderFrame();

        c.SDL_Delay(17);
    }
}
