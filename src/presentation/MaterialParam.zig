const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const c = @import("../c.zig");

const AssetInventory = @import("AssetInventory.zig").AssetInventory;
const Buffer = @import("Buffer.zig").Buffer;
const DescriptorWriter = @import("DescriptorWriter.zig").DescriptorWriter;
const RenderContext = @import("RenderContext.zig").RenderContext;
const Texture = @import("Texture.zig").Texture;

pub const MatParamError = error{};

pub const MaterialParam = struct {
    m_ptr: *anyopaque,
    m_vTable: *VTable,

    const VTable = struct {
        // write/update descriptors for this param
        writeDescriptor: *const fn (*anyopaque, binding: u32, descriptorToWrite: c.VkDescriptorSet) MatParamError!void,
    };

    pub fn WriteDescriptor(
        self: *MaterialParam,
        binding: u32,
        descriptorWriter: *DescriptorWriter,
        descriptorToWrite: c.VkDescriptorSet,
    ) MatParamError!void {
        return self.m_vTable.writeDescriptor(self.m_data, binding, descriptorWriter, descriptorToWrite);
    }

    pub fn init(obj: anytype) MaterialParam {
        const Ptr = @TypeOf(obj);
        const PtrInfo = @typeInfo(Ptr);
        assert(PtrInfo == .Pointer); // Must be a pointer
        assert(PtrInfo.Pointer.size == .One); // Must be a single-item pointer
        assert(@typeInfo(PtrInfo.Pointer.child) == .Struct); // Must point to a struct
        const impl = struct {
            fn WriteDescriptor(ptr: *anyopaque, binding: u32, descriptorWriter: *DescriptorWriter) void {
                const self: Ptr = @ptrCast(@alignCast(ptr));
                self.WriteDescriptor(binding, descriptorWriter);
            }
        };
        return .{
            .m_ptr = obj,
            .m_vTable = &.{
                .writeDescriptor = impl.WriteDescriptor,
            },
        };
    }
};

pub const TextureParam = struct {
    m_texture: *Texture,

    pub fn WriteDescriptor(
        self: *anyopaque,
        binding: u32,
        descriptorWriter: *DescriptorWriter,
    ) MatParamError!void {
        const realSelf: *TextureParam = @ptrCast(@alignCast(self));
        const rContext = try RenderContext.GetInstance();
        try descriptorWriter.WriteImage(
            binding,
            realSelf.m_texture.m_imageView,
            rContext.m_defaultSamplerLinear,
            c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
            c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        );
    }
};

pub const UniformParam = struct {
    m_data: *Buffer,
    m_dataSize: usize,
    m_offset: usize,

    pub fn WriteDescriptor(
        self: *anyopaque,
        binding: u32,
        descriptorWriter: *DescriptorWriter,
    ) MatParamError!void {
        const realSelf: *UniformParam = @ptrCast(@alignCast(self));
        try descriptorWriter.WriteBuffer(
            binding,
            realSelf.m_data.m_buffer,
            realSelf.m_dataSize,
            realSelf.m_offset,
            c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        );
    }
};
