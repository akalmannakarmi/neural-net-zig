const std = @import("std");
const NeuralNet = @import("ai.zig").NeuralNet;

pub fn main() !void {
    var nn = NeuralNet.init(std.heap.page_allocator);
    defer nn.deinit();

    try nn.load("test.tsai");
    try nn.save("test1.tsai");
}

test "simple test" {
    var nn = NeuralNet.init(std.testing.allocator);
    defer nn.deinit();

    try nn.load("test.tsai");
    try nn.save("test1.tsai");
}
