const std = @import("std");
const debug = std.debug;
const allocator = std.heap.page_allocator;
const mem = std.mem;

const filePathUtils = @import("FilePathUtils.zig");
const c = @import("../c.zig");

pub const ImageFileError = error{
    STBI_LoadFailed,
    STBI_WriteFailed,
};

pub const ImageFile = struct {
    m_imageData: [*]u8,
    m_width: u32,
    m_height: u32,
    m_channels: u16,
    m_freed: bool,

    pub fn FreeImage(self: *ImageFile) void {
        debug.assert(!self.m_freed);
        c.stbi_image_free(self.m_imageData);
        self.m_freed = true;
    }
};

pub fn LoadImage(cwdRelativePath: []const u8) !ImageFile {
    var width: c_int = undefined;
    var height: c_int = undefined;
    var channels: c_int = undefined;
    const imagePath = try filePathUtils.CwdToAbsolute(allocator, cwdRelativePath);
    defer allocator.free(imagePath);
    const image = c.stbi_load(imagePath.ptr, &width, &height, &channels, c.STBI_rgb_alpha); //TODO adjustable format
    if (image == null) {
        // could log stbi_failure_reason...
        return ImageFileError.STBI_LoadFailed;
    } else {
        return ImageFile{
            .m_imageData = image,
            .m_width = @intCast(width),
            .m_height = @intCast(height),
            .m_channels = @intCast(channels),
            .m_freed = false,
        };
    }
}

//TODO including stb_image_write.h causing compile errors
//pub fn SaveImageAs(image: *ImageFile, cwdRelativePath: []const u8) !void {
//    const ext = try filePathUtils.GetExtension(cwdRelativePath);
//    var stbiReturnCode: c_int = 0;
//    if (mem.eql(u8, ext, ".png")) {
//        stbiReturnCode = c.stbi_write_png(
//            cwdRelativePath.ptr,
//            image.m_width,
//            image.m_height,
//            image.m_channels,
//            image.m_imageData,
//            image.m_width * image.m_channels,
//        );
//    }
//    //TODO if we can ever get rid of STB_ONLY_PNG...
//    //else if (mem.eql(u8, ext, ".jpg")) {
//    //    stbiReturnCode = c.stbi_write_jpg(
//    //        cwdRelativePath.ptr,
//    //        image.m_width,
//    //        image.m_height,
//    //        image.m_channels,
//    //        image.m_imageData,
//    //        100,
//    //    );
//    //} else if (mem.eql(u8, ext, ".tga")) {
//    //    stbiReturnCode = c.stbi_write_tga(
//    //        cwdRelativePath.ptr,
//    //        image.m_width,
//    //        image.m_height,
//    //        image.m_channels,
//    //        image.m_imageData,
//    //    );
//    //} else if (mem.eql(u8, ext, ".bmp")) {
//    //    stbiReturnCode = c.stbi_write_bmp(
//    //        cwdRelativePath.ptr,
//    //        image.m_width,
//    //        image.m_height,
//    //        image.m_channels,
//    //        image.m_imageData,
//    //    );
//    //}
//    else {
//        return filePathUtils.FilePathError.InvalidExtension;
//    }
//
//    // Handle stbi failure code
//    if (stbiReturnCode == 0) {
//        return ImageFileError.STBI_WriteFailed;
//    }
//}
