const c = @import("../c.zig");
const std = @import("std");
const debug = std.debug;
const allocator = std.heap.page_allocator;

const SDLInitError = error{
    //TODO
    SDLError,
};

fn ReportSDLError(message: []const u8) void {
    const errStr = c.SDL_GetError();
    debug.print(" {s}: {s}", .{ message, errStr[0..std.mem.len(errStr)] });
}

fn SetSDLAttribute(attribute: c_int, setVal: c_int) !c_int {
    const result = c.SDL_GL_SetAttribute(@enumFromInt(attribute), setVal);
    if (result < 0) {
        ReportSDLError("Unable to set attribute");
        return SDLInitError.SDLError;
    }

    return result;
}

// caller needs to free with SDL_Quit
pub fn InitSDL() !void {
    // SDL init
    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        ReportSDLError("Unable to initialize SDL");
        return SDLInitError.SDLError;
    }
}

// caller needs to free with SDL_DestroyWindow
pub fn CreateWindow(name: [*c]const u8, width: u32, height: u32) !*c.SDL_Window {
    const window = c.SDL_CreateWindow(
        name,
        c.SDL_WINDOWPOS_UNDEFINED,
        c.SDL_WINDOWPOS_UNDEFINED,
        @intCast(width),
        @intCast(height),
        c.SDL_WINDOW_VULKAN | c.SDL_WINDOW_RESIZABLE,
    ) orelse {
        ReportSDLError("Unable to create window");
        return SDLInitError.SDLError;
    };
    return window;
}

// caller needs to free with SDL_DestroyRenderer
pub fn CreateRenderer(window: *c.SDL_Window) !*c.SDL_Renderer {
    const renderer = c.SDL_CreateRenderer(window, -1, 0) orelse {
        ReportSDLError("Unable to create renderer");
        return SDLInitError.SDLError;
    };
    return renderer;
}
