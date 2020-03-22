const stdm = @import("std").math;

pub const colorsRGB8 = @import("ColorRGB8.zig");
pub const colorsRGBA8 = @import("ColorRGBA8.zig");
pub const colorsRGBA = @import("ColorRGBA.zig");
pub const colorsRGB = @import("ColorRGB.zig");

pub const ColorRGB = struct {
    r: f32,
    g: f32,
    b: f32,
};

pub const ColorRGB8 = struct {
    r: u8,
    g: u8,
    b: u8,
};

pub const ColorRGBA = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

pub const ColorRGBA8 = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

// ToRGB
pub inline fn RGB8ToRGB(color: *const ColorRGB8) ColorRGB {
    return ColorRGB{ .r = color.r / 255.0, .g = color.g / 255.0, .b = color.b / 255 };
}

pub inline fn RGBAToRGB(color: *const ColorRGBA) ColorRGB {
    return ColorRGB{ .r = color.r, .g = color.g, .b = color.b };
}

pub inline fn RGBA8ToRGB(color: *const ColorRGBA8) ColorRGB {
    return ColorRGB{ .r = color.r, .g = color.g, .b = color.b };
}

// ToRGB8
pub inline fn RGBToRGB8(color: *const ColorRGB) ColorRGB8 {
    return ColorRGB8{ .r = zigm.round32(color.r), .g = zigm.round32(color.g), .b = zigm.round32(color.b) };
}

pub inline fn RGBAToRGB8(color: *const ColorRGBA) ColorRGB8 {
    return ColorRGB8{ .r = zigm.round32(color.r), .g = zigm.round32(color.g), .b = zigm.round32(color.b) };
}

pub inline fn RGBA8ToRGB8(color: *const ColorRGB) ColorRGB8 {
    return ColorRGB8{ .r = color.r, .g = color.g, .b = color.b };
}

// ToRGBA
pub inline fn RGBToRGBA(color: *const ColorRGB) ColorRGBA {
    return ColorRGBA{ .r = color.r, .g = color.g, .b = color.b, .a = 1.0 };
}

pub inline fn RGB8ToRGBA(color: *const ColorRGBA) ColorRGBA {
    return ColorRGBA{ .r = color.r / 255.0, .g = color.g / 255.0, .b = color.b / 255.0, .a = 1.0 };
}

pub inline fn RGBA8ToRGBA(color: *const ColorRGB8) ColorRGBA {
    return ColorRGBA{ .r = color.r / 255.0, .g = color.g / 255.0, .b = color.b / 255.0, .a = color.a / 255.0 };
}

// ToRGBA8
pub inline fn RGBToRGBA8(color: *const ColorRGB) ColorRGBA8 {
    return ColorRGBA8{ .r = zigm.round32(color.r * 255.0), .g = zigm.round32(color.g * 255.0), .b = zigm.round32(color.b * 255.0), .a = 255 };
}

pub inline fn RGBAToRGBA8(color: *const ColorRGBA) ColorRGBA8 {
    return ColorRGBA8{ .r = zigm.round32(color.r * 255.0), .g = zigm.round32(color.g * 255.0), .b = zigm.round32(color.b * 255.0), .a = zigm.round32(color.a * 255.0) };
}

pub inline fn RGB8ToRGBA8(color: *const ColorRGB) ColorRGBA8 {
    return ColorRGBA8{ .r = color.r, .g = color.g, .b = color.b, .a = 255 };
}

//TODO testing: conversions back and forth?
