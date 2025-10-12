const std = @import("std");
const Type = std.builtin.Type;

pub const StructOptions = struct {
    // prints a new line at the end
    newLine: bool = false,

    // prints the dereferenced value of a pointer in addition to the address
    derefPointers: bool = false,

    // recursively prints struct fields
    //recurse: bool = false,

    // limits how many times we recursively print child structs, 0 = infinite
    //recurseLevels: uint8 = 0,
};

// Print a struct type
pub fn DebugPrintStruct(
    comptime T: type,
    instance: *const T,
    options: StructOptions,
) void {
    //TODO take a logger/print fn as input?
    //TODO make the function have an option to recurse and have indentation stack
    std.debug.assert(@typeInfo(T) == .@"struct");
    std.debug.print("{s} {{\n", .{@typeName(T)});
    inline for (std.meta.fields(T)) |field| {
        switch (field.type) {
            .pointer => {
                const pointerAddress = @field(instance, field.name);
                if (options.derefPointers) {
                    std.debug.print(
                        "  {s}: {s} = {any}",
                        .{
                            field.name,
                            @typeName(field.type),
                            pointerAddress,
                        },
                    );
                } else {
                    std.debug.print(
                        "  {s}: {s} = {any}",
                        .{
                            field.name,
                            @typeName(field.type),
                            pointerAddress,
                        },
                    );
                }
            },
            else => {
                const fieldValue = @field(instance, field.name);
                std.debug.print(
                    "  {s}: {s} = {any}",
                    .{
                        field.name,
                        @typeName(field.type),
                        fieldValue,
                    },
                );
            }
        }
    }
    if (options.newLine) {
        std.debug.print("}}\n", .{});
    } else {
        std.debug.print("}}", .{});
    }
}
