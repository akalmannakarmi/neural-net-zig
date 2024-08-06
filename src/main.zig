const std = @import("std");
const Link = @import("structs.zig").Link;
const Operation = @import("structs.zig").Operation;
const NeuralNet = @import("ai.zig").NeuralNet;

pub fn main() !void {
    var nn = NeuralNet.init(std.heap.page_allocator);
    // defer nn.deinit();
    var empty_links: []Link = &[_]Link{};

    try nn.create(1_000_000, 1_000, 100_000_000, 10_000_000, empty_links[0..]);
    try nn.save("test.tsai");
    nn.deinit();

    var nn1 = NeuralNet.init(std.heap.page_allocator);
    // defer nn1.deinit();

    try nn1.load("test.tsai");
    try nn1.addNodes(5000, 100, 50_000, 1_000_000);
    try nn1.save("test1.tsai");
    nn1.deinit();
}

test "simple test" {
    var nn = NeuralNet.init(std.testing.allocator);
    defer nn.deinit();

    try nn.load("test.tsai");
    try nn.save("test1.tsai");
}
