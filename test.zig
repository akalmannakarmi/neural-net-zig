const std = @import("std");

const MyEnum = enum(u32) {
    Variant1 = 1,
    Variant2 = 2,
    Variant3 = 3,
};

pub fn main() void {
    const size_of_enum = @sizeOf(MyEnum);
    std.debug.print("Size of MyEnum: {} bytes\n", .{size_of_enum});
}
