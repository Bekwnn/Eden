const c = @import("c.zig");

pub const ModifierKey = enum {
    Shift,
    Ctrl,
    Alt,
    None,
};

pub fn GetModifierDown(keybState: [*c]const u8, modifier: ModifierKey) bool {
    switch (modifier) {
        ModifierKey.Shift => {
            if (keybState[c.SDL_SCANCODE_LSHIFT] != 0 or
                keybState[c.SDL_SCANCODE_RSHIFT] != 0)
            {
                return true;
            }
        },
        ModifierKey.Ctrl => {
            if (keybState[c.SDL_SCANCODE_LCTRL] != 0 or
                keybState[c.SDL_SCANCODE_RCTRL] != 0)
            {
                return true;
            }
        },
        ModifierKey.Alt => {
            if (keybState[c.SDL_SCANCODE_LALT] != 0 or
                keybState[c.SDL_SCANCODE_RALT] != 0)
            {
                return true;
            }
        },
        ModifierKey.None => {
            if (keybState[c.SDL_SCANCODE_LCTRL] == 0 and
                keybState[c.SDL_SCANCODE_RCTRL] == 0 and
                keybState[c.SDL_SCANCODE_LSHIFT] == 0 and
                keybState[c.SDL_SCANCODE_RSHIFT] == 0 and
                keybState[c.SDL_SCANCODE_LALT] == 0 and
                keybState[c.SDL_SCANCODE_RALT] == 0)
            {
                return true;
            }
        },
    }
    return false;
}

pub fn GetKeyState(keyscanCode: u32, modifier: ?ModifierKey) bool {
    const keybState = c.SDL_GetKeyboardState(null);
    if (modifier) |mod| {
        if (!GetModifierDown(keybState, mod)) {
            return false;
        }
    }

    if (keybState[keyscanCode] == 0) {
        return false;
    }

    return true;
}
