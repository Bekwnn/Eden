const stdm = @import("std").math;

pub const colorsRGB8 = @import("ColorRGB8.zig");
pub const colorsRGBA8 = @import("ColorRGBA8.zig");
pub const colorsRGBA = @import("ColorRGBA.zig");
pub const colorsRGB = @import("ColorRGB.zig");

fn ColorEquals(comptime colorType: type, lhs: *const colorType, rhs: *const colorType) bool {
    const fieldNames = .{
        "r",
        "g",
        "b",
        "a",
        "h",
        "s",
        "v",
    };

    for (fieldNames) |fieldName| {
        if (@hasField(colorType, fieldName)) {
            if (@field(lhs, fieldName) != @field(rhs, fieldName)) return false;
        }
    }
    return true;
}

pub const ColorRGB = packed struct {
    r: f32,
    g: f32,
    b: f32,

    pub fn Equals(self: *const ColorRGB, other: *const ColorRGB) bool {
        return ColorEquals(ColorRGB, self, other);
    }
};

pub const ColorRGB8 = packed struct {
    r: u8,
    g: u8,
    b: u8,
    pub fn Equals(self: *const ColorRGB8, other: *const ColorRGB8) bool {
        return ColorEquals(ColorRGB8, self, other);
    }
};

pub const ColorRGBA = packed struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,
    pub fn Equals(self: *const ColorRGBA, other: *const ColorRGBA) bool {
        return ColorEquals(ColorRGBA, self, other);
    }
};

pub const ColorRGBA8 = packed struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
    pub fn Equals(self: *const ColorRGBA8, other: *const ColorRGBA8) bool {
        return ColorEquals(ColorRGBA8, self, other);
    }
};

pub const ColorHSV = packed struct {
    h: f32, // angle in degrees
    s: f32, // 0 to 1
    v: f32, // 0 to 1

    pub fn Equals(self: *const ColorHSV, other: *const ColorHSV) bool {
        return ColorEquals(ColorHSV, self, other);
    }
};

// FromHSV
//TODO HSV8 / RGB8 version
pub fn HSVToRGB(color: *const ColorHSV) ColorRGB {
    if (color.s == 0.0) { // grey-scale
        return ColorRGB{ .r = color.v, .g = color.v, .b = color.v };
    }

    const hh = color.h / 60.0;
    const i = @floatToInt(u8, hh);
    const ff = hh - @intToFloat(f32, i);
    const p = color.v * (1.0 - color.s);
    const q = color.v * (1.0 - (color.s * ff));
    const t = color.v * (1.0 - (color.s * (1.0 - ff)));

    return switch (i) {
        0 => ColorRGB{ .r = color.v, .g = t, .b = p },
        1 => ColorRGB{ .r = q, .g = color.v, .b = p },
        2 => ColorRGB{ .r = p, .g = color.v, .b = t },
        3 => ColorRGB{ .r = p, .g = q, .b = color.v },
        4 => ColorRGB{ .r = t, .g = p, .b = color.v },
        else => ColorRGB{ .r = color.v, .g = p, .b = q },
    };
}

// ToHSV
//TODO HSV8 / RGB8 version
pub fn RGBToHSV(color: *const ColorRGB) ColorHSV {
    const min = stdm.min(stdm.min(color.r, color.g), color.b);
    const max = stdm.max(stdm.max(color.r, color.g), color.b);
    const delta = max - min;

    var outHSV = ColorHSV{ .h = 0.0, .s = 0.0, .v = max };

    if (delta < stdm.f32_epsilon) //grey-scale color
    {
        return outHSV;
    } else {
        outHSV.s = (delta / max);
    }

    if (color.r >= max) {
        outHSV.h = (color.g - color.b) / delta; // between magenta & yellow
    } else {
        if (color.g >= max) {
            outHSV.h = 2.0 + (color.b - color.r) / delta; // between cyan & yellow
        } else {
            outHSV.h = 4.0 + (color.r - color.g) / delta; // between magenta & cyan
        }
    }

    outHSV.h *= 60.0; // degrees

    if (outHSV.h < 0.0)
        outHSV.h += 360.0;

    return outHSV;
}

// ToRGB
pub fn RGB8ToRGB(color: *const ColorRGB8) ColorRGB {
    return ColorRGB{
        .r = @intToFloat(f32, color.r) / 255.0,
        .g = @intToFloat(f32, color.g) / 255.0,
        .b = @intToFloat(f32, color.b) / 255.0,
    };
}

pub fn RGBAToRGB(color: *const ColorRGBA) ColorRGB {
    return ColorRGB{
        .r = color.r,
        .g = color.g,
        .b = color.b,
    };
}

pub fn RGBA8ToRGB(color: *const ColorRGBA8) ColorRGB {
    return ColorRGB{
        .r = color.r,
        .g = color.g,
        .b = color.b,
    };
}

// ToRGB8
pub fn RGBToRGB8(color: *const ColorRGB) ColorRGB8 {
    return ColorRGB8{
        .r = @floatToInt(u8, stdm.round(color.r * 255.0)),
        .g = @floatToInt(u8, stdm.round(color.g * 255.0)),
        .b = @floatToInt(u8, stdm.round(color.b * 255.0)),
    };
}

pub fn RGBAToRGB8(color: *const ColorRGBA) ColorRGB8 {
    return ColorRGB8{
        .r = @floatToInt(u8, stdm.round(color.r * 255.0)),
        .g = @floatToInt(u8, stdm.round(color.g * 255.0)),
        .b = @floatToInt(u8, stdm.round(color.b * 255.0)),
    };
}

pub fn RGBA8ToRGB8(color: *const ColorRGB) ColorRGB8 {
    return ColorRGB8{
        .r = color.r,
        .g = color.g,
        .b = color.b,
    };
}

// ToRGBA
pub fn RGBToRGBA(color: *const ColorRGB) ColorRGBA {
    return ColorRGBA{
        .r = color.r,
        .g = color.g,
        .b = color.b,
        .a = 1.0,
    };
}

pub fn RGB8ToRGBA(color: *const ColorRGB8) ColorRGBA {
    return ColorRGBA{
        .r = @intToFloat(f32, color.r) / 255.0,
        .g = @intToFloat(f32, color.g) / 255.0,
        .b = @intToFloat(f32, color.b) / 255.0,
        .a = 1.0,
    };
}

pub fn RGBA8ToRGBA(color: *const ColorRGBA8) ColorRGBA {
    return ColorRGBA{
        .r = @intToFloat(f32, color.r) / 255.0,
        .g = @intToFloat(f32, color.g) / 255.0,
        .b = @intToFloat(f32, color.b) / 255.0,
        .a = @intToFloat(f32, color.a) / 255.0,
    };
}

// ToRGBA8
pub fn RGBToRGBA8(color: *const ColorRGB) ColorRGBA8 {
    return ColorRGBA8{
        .r = @floatToInt(u8, stdm.round(color.r * 255.0)),
        .g = @floatToInt(u8, stdm.round(color.g * 255.0)),
        .b = @floatToInt(u8, stdm.round(color.b * 255.0)),
        .a = 255,
    };
}

pub fn RGBAToRGBA8(color: *const ColorRGBA) ColorRGBA8 {
    return ColorRGBA8{
        .r = @floatToInt(u8, stdm.round(color.r * 255.0)),
        .g = @floatToInt(u8, stdm.round(color.g * 255.0)),
        .b = @floatToInt(u8, stdm.round(color.b * 255.0)),
        .a = @floatToInt(u8, stdm.round(color.a * 255.0)),
    };
}

pub fn RGB8ToRGBA8(color: *const ColorRGB8) ColorRGBA8 {
    return ColorRGBA8{
        .r = color.r,
        .g = color.g,
        .b = color.b,
        .a = 255,
    };
}

const std = @import("std");
const expect = std.testing.expect;

test "Color 8bit to f32 conversion" {
    const testColors = [_]ColorRGB8{
        colorsRGB8.Red,
        colorsRGB8.Green,
        colorsRGB8.Blue,
        colorsRGB8.Cyan,
        colorsRGB8.Yellow,
        colorsRGB8.Magenta,
    };
    for (testColors) |color| {
        const colorConverted = RGB8ToRGB(&color);
        const colorConvertedBack = RGBToRGB8(&colorConverted);
        expect(color.Equals(&colorConvertedBack));
    }
}

test "Color 8bit to f32 conversion with alpha" {
    const testColors = [_]ColorRGBA8{
        colorsRGBA8.Red,
        colorsRGBA8.Green,
        colorsRGBA8.Blue,
        colorsRGBA8.Cyan,
        colorsRGBA8.Yellow,
        colorsRGBA8.Magenta,
    };
    for (testColors) |color| {
        const colorConverted = RGBA8ToRGBA(&color);
        const colorConvertedBack = RGBAToRGBA8(&colorConverted);
        expect(color.Equals(&colorConvertedBack));
    }
}

test "Color RGB to HSV and HSV to RGB" {
    const testColors = [_]ColorRGB{
        colorsRGB.Red,
        colorsRGB.Green,
        colorsRGB.Blue,
        colorsRGB.Cyan,
        colorsRGB.Yellow,
        colorsRGB.Magenta,
    };
    for (testColors) |color| {
        const colorConverted = RGBToHSV(&color);
        const colorConvertedBack = HSVToRGB(&colorConverted);
        expect(color.Equals(&colorConvertedBack));
    }
}
