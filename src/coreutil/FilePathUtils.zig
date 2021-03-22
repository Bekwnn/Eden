const std = @import("std");
const process = std.process;
const fmt = std.fmt;
const mem = std.mem;

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
