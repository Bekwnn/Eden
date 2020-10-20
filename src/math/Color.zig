const stdm = @import("std").math;

pub const colorsRGB8 = @import("ColorRGB8.zig");
pub const colorsRGBA8 = @import("ColorRGBA8.zig");
pub const colorsRGBA = @import("ColorRGBA.zig");
pub const colorsRGB = @import("ColorRGB.zig");

pub const ColorRGB = packed struct {
    r: f32,
    g: f32,
    b: f32,
};

pub const ColorRGB8 = packed struct {
    r: u8,
    g: u8,
    b: u8,
};

pub const ColorRGBA = packed struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

pub const ColorRGBA8 = packed struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

pub const ColorHSV = packed struct {
    h: f32, // angle in degrees
    s: f32, // 0 to 1
    v: f32, // 0 to 1
};

// FromHSV
//TODO HSV8 / RGB8 version
pub inline fn HSVToRGB(color: *const ColorHSV) ColorRGB {
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
pub inline fn RGBToHSV(color: *const ColorRGB) ColorHSV {
    const min = zigm.min(zigm.min(color.r, color.g), color.b);
    const max = zigm.max(zigm.max(color.r, color.g), color.b);
    const delta = max - min;

    var outHSV = ColorHSV{ .h = 0.0, .s = 0.0, .v = max };

    if (delta < zigm.f32_epsilon) //grey-scale color
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
