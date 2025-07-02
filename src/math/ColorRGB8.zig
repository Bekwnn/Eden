const Color = @import("Color.zig");

// All const colors derived from RGB8 since hex colors are easy to find
pub const Black = Color.ColorRGB8{ .r = 0, .g = 0, .b = 0 };
pub const White = Color.ColorRGB8{ .r = 255, .g = 255, .b = 255 };

pub const Red = Color.ColorRGB8{ .r = 255, .g = 0, .b = 0 };
pub const Green = Color.ColorRGB8{ .r = 0, .g = 255, .b = 0 };
pub const Blue = Color.ColorRGB8{ .r = 0, .g = 0, .b = 255 };

pub const Cyan = Color.ColorRGB8{ .r = 0, .g = 255, .b = 255 };
pub const Yellow = Color.ColorRGB8{ .r = 255, .g = 255, .b = 0 };
pub const Magenta = Color.ColorRGB8{ .r = 255, .g = 0, .b = 255 };
