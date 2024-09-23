const std = @import("std");
const Link = @import("structs.zig").Link;
const Operation = @import("structs.zig").Operation;
const NeuralNet = @import("ai.zig").NeuralNet;
const RanTrain = @import("train.zig");

pub fn main() !void {
    std.debug.print("Creating NN\n", .{});
    var start = std.time.timestamp();
    var nn = try RanTrain.createRandom(std.heap.page_allocator, 10, 10, 1, 1);
    std.debug.print("Completed {}s\n", .{std.time.timestamp() - start});

    std.debug.print("Copying NN\n", .{});
    start = std.time.timestamp();
    var nn1 = try RanTrain.createRnCopy(&nn, 100);
    std.debug.print("Completed {}s\n", .{std.time.timestamp() - start});

    std.debug.print("Copying NN1\n", .{});
    start = std.time.timestamp();
    _ = try RanTrain.createRnCopy(&nn1, 10);
    std.debug.print("Completed {}s\n", .{std.time.timestamp() - start});

    std.debug.print("Saving nn\n", .{});
    start = std.time.milliTimestamp();
    try nn.save("nn.tsai");
    std.debug.print("Completed {}ms\n", .{std.time.milliTimestamp() - start});

    std.debug.print("Saving nn1\n", .{});
    start = std.time.milliTimestamp();
    try nn1.save("nn1.tsai");
    std.debug.print("Completed {}ms\n", .{std.time.milliTimestamp() - start});

    std.debug.print("Running nn\n", .{});
    start = std.time.milliTimestamp();
    nn.setInputs(&[_]f64{ 456, 832, 94, 8237, 238, 86, 6456, 345, 12, 10 });
    nn.process();
    var output = nn.getOutputs();
    std.debug.print("Output:{any}\n", .{output});

    std.debug.print("Running nn1\n", .{});
    start = std.time.milliTimestamp();
    nn1.setInputs(&[_]f64{ 6235, 634, 586, 234, 453, 457, 723, 8235, 844253, 23567 });
    nn1.process();
    output = nn1.getOutputs();
    std.debug.print("Output:{any}\n", .{output});

    std.debug.print("Completed {}ms\n", .{std.time.milliTimestamp() - start});
}
