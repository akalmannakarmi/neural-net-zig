const std = @import("std");
const Link = @import("structs.zig").Link;
const Operation = @import("structs.zig").Operation;
const NeuralNet = @import("ai.zig").NeuralNet;
const RanTrain = @import("train.zig");

pub fn main() !void {
    var nn = try RanTrain.createRandom(std.heap.page_allocator, 100, 4, 100, 10);
    var nn1 = try RanTrain.createRnCopy(&nn, 100);
    _ = try RanTrain.createRnCopy(&nn1, 10);
}
