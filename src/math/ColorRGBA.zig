const Color = @import("Color.zig");

// All const colors derived from RGB8 since hex colors are easy to find
pub const Black = Color.RGB8ToRGBA(&Color.colorsRGB8.Black);
pub const White = Color.RGB8ToRGBA(&Color.colorsRGB8.White);

pub const Red = Color.RGB8ToRGBA(&Color.colorsRGB8.Red);
pub const Green = Color.RGB8ToRGBA(&Color.colorsRGB8.Green);
pub const Blue = Color.RGB8ToRGBA(&Color.colorsRGB8.Blue);

pub const Cyan = Color.RGB8ToRGBA(&Color.colorsRGB8.Cyan);
pub const Yellow = Color.RGB8ToRGBA(&Color.colorsRGB8.Yellow);
pub const Magenta = Color.RGB8ToRGBA(&Color.colorsRGB8.Magenta);
