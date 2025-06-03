const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const assert = std.debug.assert;

const c = @import("../c.zig");

const AssetInventory = @import("AssetInventory.zig").AssetInventory;
const Buffer = @import("Buffer.zig").Buffer;
const DescriptorWriter = @import("DescriptorWriter.zig").DescriptorWriter;
const renderContext = @import("RenderContext.zig");
const RenderContext = renderContext.RenderContext;
const Texture = @import("Texture.zig").Texture;

pub const MaterialParam = struct {
    m_ptr: *anyopaque,
    m_vTable: *const VTable,
    m_binding: u32,

    const VTable = struct {
        // write/update descriptors for this param
        writeDescriptor: *const fn (*anyopaque, binding: u32, descriptorWriter: *DescriptorWriter) Error!void,

        deinit: *const fn (ptr: *anyopaque, allocator: Allocator) void,
    };
    pub const Error = error{
        WriteDescriptorError,
    };

    pub fn deinit(self: *MaterialParam, allocator: Allocator) void {
        self.m_vTable.deinit(self.m_ptr, allocator);
    }

    pub fn WriteDescriptor(
        self: *MaterialParam,
        descriptorWriter: *DescriptorWriter,
    ) Error!void {
        return try self.m_vTable.writeDescriptor(self.m_ptr, self.m_binding, descriptorWriter);
    }

    pub fn init(obj: anytype, binding: u32) MaterialParam {
        const Ptr = @TypeOf(obj);
        const PtrInfo = @typeInfo(Ptr);
        assert(PtrInfo == .pointer); // Must be a pointer
        assert(PtrInfo.pointer.size == .one); // Must be a single-item pointer
        assert(@typeInfo(PtrInfo.pointer.child) == .@"struct"); // Must point to a struct
        const impl = struct {
            fn WriteDescriptor(ptr: *anyopaque, bindingSlot: u32, descriptorWriter: *DescriptorWriter) !void {
                const self: Ptr = @ptrCast(@alignCast(ptr));
                try self.WriteDescriptor(bindingSlot, descriptorWriter);
            }

            fn deinit(ptr: *anyopaque, allocator: Allocator) void {
                const self: Ptr = @ptrCast(@alignCast(ptr));
                self.deinit(allocator);
            }
        };
        return MaterialParam{
            .m_ptr = obj,
            .m_vTable = &VTable{
                .writeDescriptor = impl.WriteDescriptor,
                .deinit = impl.deinit,
            },
            .m_binding = binding,
        };
    }
};

pub const TextureParam = struct {
    m_texture: *Texture,

    // allocates the parameter, later freed via vTable with deinit()
    pub fn init(allocator: Allocator, texture: *Texture) !*TextureParam {
        const newPtr = try allocator.create(TextureParam);
        newPtr.m_texture = texture;
        return newPtr;
    }

    pub fn deinit(self: *TextureParam, allocator: Allocator) void {
        allocator.destroy(self);
    }

    pub fn WriteDescriptor(
        self: *TextureParam,
        binding: u32,
        descriptorWriter: *DescriptorWriter,
    ) MaterialParam.Error!void {
        const rContext = RenderContext.GetInstance() catch {
            return MaterialParam.Error.WriteDescriptorError;
        };
        descriptorWriter.WriteImage(
            binding,
            self.m_texture.m_imageView,
            rContext.m_defaultSamplerLinear,
            c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
            c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        ) catch {
            return MaterialParam.Error.WriteDescriptorError;
        };
    }
};

pub const UniformParam = struct {
    m_data: *Buffer,
    m_dataSize: usize,
    m_offset: usize,

    // allocates the parameter, later freed with deinit()
    pub fn init(
        allocator: Allocator,
        data: *Buffer,
        dataSize: usize,
        offset: usize,
    ) !*UniformParam {
        const newPtr = try allocator.create(UniformParam);
        newPtr.m_data = data;
        newPtr.m_dataSize = dataSize;
        newPtr.m_offset = offset;
        return newPtr;
    }

    pub fn deinit(self: *UniformParam, allocator: Allocator) void {
        allocator.destroy(self);
    }

    pub fn WriteDescriptor(
        self: *UniformParam,
        binding: u32,
        descriptorWriter: *DescriptorWriter,
    ) MaterialParam.Error!void {
        descriptorWriter.WriteBuffer(
            binding,
            self.m_data.m_buffer,
            self.m_dataSize,
            self.m_offset,
            c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        ) catch {
            return MaterialParam.Error.WriteDescriptorError;
        };
    }
};
