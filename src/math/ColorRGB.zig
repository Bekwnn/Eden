const Color = @import("Color.zig");

// All const colors derived from RGB8 since hex colors are easy to find
pub const Black = Color.RGB8ToRGB(&Color.ColorRGB8.presets.Black);
pub const White = Color.RGB8ToRGB(&Color.ColorRGB8.presets.White);

pub const Red = Color.RGB8ToRGB(&Color.ColorRGB8.presets.Red);
pub const Green = Color.RGB8ToRGB(&Color.ColorRGB8.presets.Green);
pub const Blue = Color.RGB8ToRGB(&Color.ColorRGB8.presets.Blue);

pub const Cyan = Color.RGB8ToRGB(&Color.ColorRGB8.presets.Cyan);
pub const Yellow = Color.RGB8ToRGB(&Color.ColorRGB8.presets.Yellow);
pub const Magenta = Color.RGB8ToRGB(&Color.ColorRGB8.presets.Magenta);
