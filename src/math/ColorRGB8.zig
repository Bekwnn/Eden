usingnamespace @import("Color.zig");

// All const colors derived from RGB8 since hex colors are easy to find
pub const Black = ColorRGB8{ .r = 0, .g = 0, .b = 0 };
pub const White = ColorRGB8{ .r = 255, .g = 255, .b = 255 };

pub const Red = ColorRGB8{ .r = 255, .g = 0, .b = 0 };
pub const Green = ColorRGB8{ .r = 0, .g = 255, .b = 0 };
pub const Blue = ColorRGB8{ .r = 0, .g = 0, .b = 255 };

pub const Cyan = ColorRGB8{ .r = 0, .g = 255, .b = 255 };
pub const Yellow = ColorRGB8{ .r = 255, .g = 255, .b = 0 };
pub const Magenta = ColorRGB8{ .r = 255, .g = 0, .b = 0 };
