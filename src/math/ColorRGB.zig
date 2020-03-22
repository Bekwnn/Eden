usingnamespace @import("Color.zig");

// All const colors derived from RGB8 since hex colors are easy to find
pub const Black = comptime RGB8ToRGB(colorsRGB8.Black);
pub const White = comptime RGB8ToRGB(colorsRGB8.White);

pub const Red = comptime RGB8ToRGB(colorsRGB8.Red);
pub const Green = comptime RGB8ToRGB(colorsRGB8.Green);
pub const Blue = comptime RGB8ToRGB(colorsRGB8.Blue);

pub const Cyan = comptime RGB8ToRGB(colorsRGB8.Cyan);
pub const Yellow = comptime RGB8ToRGB(colorsRGB8.Yellow);
pub const Magenta = comptime RGB8ToRGB(colorsRGB8.Magenta);
