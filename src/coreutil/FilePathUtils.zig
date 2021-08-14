const std = @import("std");
const process = std.process;
const fmt = std.fmt;
const mem = std.mem;

pub const FilePathError = error{
    InvalidExtension,
};

// Caller must free if successful
// TODO: Only supports back slashes; process.GetCwdAlloc() returns a backslash'd path
pub fn CwdToAbsolute(allocator: *mem.Allocator, relativePath: []const u8) ![]u8 {
    const cwdPath = try process.getCwdAlloc(allocator);
    defer allocator.free(cwdPath);
    var absolutePath = try allocator.alloc(u8, cwdPath.len + relativePath.len + 1);
    errdefer allocator.free(absolutePath);
    // insert forward slash if it doesn't exist
    if (relativePath.len > 0 and relativePath[0] == '\\') {
        _ = try fmt.bufPrint(absolutePath, "{s}{s}", .{ cwdPath, relativePath });
    } else {
        _ = try fmt.bufPrint(absolutePath, "{s}\\{s}", .{ cwdPath, relativePath });
    }
    return absolutePath;
}

pub fn GetExtension(relativePath: []const u8) ![]const u8 {
    var i: usize = 0;
    const pathTestEnd: usize = relativePath.len - 1;
    while (i < pathTestEnd) {
        if (relativePath[i] == '.') {
            break;
        }
        i += 1;
    }
    if (i == pathTestEnd) {
        return FilePathError.InvalidExtension;
    } else {
        return relativePath[i..relativePath.len];
    }
}

pub fn DirToString(allocator: *mem.Allocator, dir: Dir) ![]const u8 {}
