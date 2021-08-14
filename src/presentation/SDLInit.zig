usingnamespace @import("../c.zig");
const std = @import("std");
const debug = std.debug;
const allocator = std.heap.page_allocator;

const SDLInitError = error{
    //TODO
    SDLError,
};

fn ReportSDLError(message: []const u8) void {
    const errStr = SDL_GetError();
    debug.warn(" {s}: {s}", .{ message, errStr[0..std.mem.len(errStr)] });
}

fn SetSDLAttribute(attribute: c_int, setVal: c_int) !c_int {
    const result = SDL_GL_SetAttribute(@intToEnum(SDL_GLattr, attribute), setVal);
    if (result < 0) {
        ReportSDLError("Unable to set attribute");
        return SDLInitError.SDLError;
    }

    return result;
}

// caller needs to free with SDL_Quit
pub fn InitSDL() !void {
    // SDL init
    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        ReportSDLError("Unable to initialize SDL");
        return SDLInitError.SDLError;
    }
}

// caller needs to free with SDL_DestroyWindow
pub fn CreateWindow(name: [*c]const u8, width: u32, height: u32) !*SDL_Window {
    const window = SDL_CreateWindow(name, SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 1280, 720, SDL_WINDOW_VULKAN | SDL_WINDOW_RESIZABLE) orelse {
        ReportSDLError("Unable to create window");
        return SDLInitError.SDLError;
    };
    return window;
}

// caller needs to free with SDL_DestroyRenderer
pub fn CreateRenderer(window: *SDL_Window) !*SDL_Renderer {
    const renderer = SDL_CreateRenderer(window, -1, 0) orelse {
        ReportSDLError("Unable to create renderer");
        return SDLInitError.SDLError;
    };
    return renderer;
}
