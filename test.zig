const std = @import("std");

const MyStruct = struct {
    inputNodes: u64,
    outputNodes: u64,
    tempNodes: u64,
    memNodes: u64,
    allocator: std.mem.Allocator,
    nodes: std.ArrayList(f64),

    pub fn init(allocator: std.mem.Allocator) !MyStruct {
        const self = MyStruct{
            .inputNodes = 0,
            .outputNodes = 0,
            .tempNodes = 0,
            .memNodes = 0,
            .allocator = allocator,
            .nodes = std.ArrayList(f64).init(allocator), // Initialize the ArrayList properly
        };
        return self;
    }

    pub fn deinit(self: *MyStruct) void {
        self.nodes.deinit();
    }
};

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var my_struct = MyStruct.init(allocator) catch unreachable;
    defer my_struct.deinit();

    // Use `my_struct` and its `nodes` ArrayList here
}
