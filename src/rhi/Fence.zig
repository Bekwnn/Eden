const Fence = @This();

pub const VTable = struct {
    wait: *const fn () void,

    is_signaled: *const fn () void,

    reset: *const fn () void,
};
