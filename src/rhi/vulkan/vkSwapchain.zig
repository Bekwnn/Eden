const Swapchain = @import("../Swapchain.zig");

pub const vtable: Swapchain.VTable = .{
    .acquire = ,
    .present = ,

    .get_image = ,
    .get_image_count = ,

    .get_extent = ,
    .get_format = ,
};
