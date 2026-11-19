const Swapchain = @This();

pub const VTable = struct {
    acquire: *const fn () void,

    present: *const fn () void,

    get_image: *const fn (
        index: usize,
    ) void,

    get_image_count: *const fn () usize,

    get_extent: *const fn () void,

    get_format: *const fn () void,
};
