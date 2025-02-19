const std = @import("std");
const Type = std.builtin.Type;

pub fn DebugPrintStruct(comptime T: type, instance: *const T) void {
    //TODO take a logger/print fn as input?
    //TODO make the function recursive and have indentation stack
    std.debug.print("{s} {{\n", .{@typeName(T)});
    inline for (std.meta.fields(T)) |field| {
        const fieldValue = @field(instance, field.name);
        std.debug.print(
            "  {s}: {s} = {any}\n",
            .{
                field.name,
                @typeName(field.type),
                fieldValue,
            },
        );
    }
}
