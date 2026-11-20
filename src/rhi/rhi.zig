pub const BindGroup = @import("BindGroup.zig");
pub const Buffer = @import("Buffer.zig");
pub const CommandAllocator = @import("CommandAllocator.zig");
pub const CommandBuffer = @import("CommandBuffer.zig");
pub const Device = @import("Device.zig");
pub const Fence = @import("Fence.zig");
pub const Pipeline = @import("Pipeline.zig");
pub const Semaphore = @import("Semaphore.zig");
pub const Swapchain = @import("Swapchain.zig");
pub const Texture = @import("Texture.zig");

pub const Backend = enum {
    None,
    Vulkan,
    D3D12, // not implemented
    Metal, // not implemented
};

//TODO how to handle backend selection?
