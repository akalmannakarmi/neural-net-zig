const std = @import("std");
const Link = @import("structs.zig").Link;
const Operation = @import("structs.zig").Operation;
const NeuralNet = @import("ai.zig").NeuralNet;
const Random = std.Random;

var defPrng = Random.DefaultPrng.init(0);
var rng = defPrng.random();

pub fn createRandom(allocator: std.mem.Allocator, input: u64, output: u64, temp: u64, mem: u64) !NeuralNet {
    const totalNodes = input + temp + mem + output;
    var links = std.ArrayList(Link).init(allocator);
    var nodes = std.ArrayList(u64).init(allocator);
    var bitSet = try std.DynamicBitSet.initEmpty(allocator, totalNodes);
    try nodes.ensureTotalCapacity(totalNodes);

    for (totalNodes..totalNodes + output) |out| {
        try nodes.append(out);
        bitSet.unset(out);
    }

    var bitSetCount = totalNodes;
    var i: u64 = 1;
    while (nodes.items.len > 0) : (i += 1) {
        const oldLen = nodes.items.len;
        var index: usize = 0;
        while (index < oldLen) : (index += 1) {
            const dest = nodes.items[index];
            if (!bitSet.isSet(dest)) {
                bitSet.set(dest);
                bitSetCount -= 1;
            }
            const src = rng.uintLessThan(u64, totalNodes);
            if (src == dest or bitSet.isSet(src)) continue;
            try links.append(.{
                .dest = dest,
                .src = src,
                .weight = rng.floatNorm(f64),
                .op = rng.enumValue(Operation),
            });
            nodes.appendAssumeCapacity(src);
            const value = rng.weightedIndex(u64, &[_]u64{ 10, i });
            if (value == 1) {
                _ = nodes.orderedRemove(index);
                index -= 1;
            }
        }
    }
    var nn = NeuralNet.init(allocator);
    try nn.create(input, output, temp, mem, links.items);

    // Setting random mem nodes
    for (nn.nodes.items, nn.inputNodes + nn.tempNodes..nn.nodes.items.len - nn.outputNodes) |*value, _| {
        value.* = rng.floatNorm(f64);
    }
    return nn;
}

pub fn createRnCopy(self: *const NeuralNet, learnRate: u64) !NeuralNet {
    var copy = try self.clone();

    // Adding Nodes
    var value = rng.weightedIndex(u64, &[_]u64{ 10, learnRate });
    if (value == 1) {
        try copy.addNodes(0, 0, rng.uintLessThan(u64, 10), rng.uintLessThan(u64, 10));
    }

    // Updating/Removing Nodes
    value = rng.weightedIndex(u64, &[_]u64{ 10, learnRate / 2, learnRate });
    var i: u64 = 0;
    while (value > 0) : (i += 1) {
        if (value == 1) {
            _ = copy.nodes.orderedRemove(rng.intRangeLessThan(usize, copy.inputNodes, copy.nodes.items.len - copy.outputNodes));
        } else {
            const index = rng.intRangeLessThan(usize, copy.inputNodes + copy.tempNodes, copy.nodes.items.len - copy.outputNodes);
            copy.nodes.items[index] += rng.floatNorm(f64);
        }
        value = rng.weightedIndex(u64, &[_]u64{ 10 + i, learnRate });
    }

    // Adding/Updating Links
    var links = std.ArrayList(Link).init(copy.allocator);
    var bitSet = try std.DynamicBitSet.initEmpty(copy.allocator, copy.nodes.items.len);

    const linksSlice = copy.links.slice();
    const dests: []u64 = linksSlice.items(.dest);
    for (dests, 0..) |dest, index| {
        bitSet.set(dest);
        value = rng.weightedIndex(u64, &[_]u64{ 10 + links.items.len, learnRate / 2, learnRate });
        if (value == 1) {
            const src = rng.uintLessThan(u64, copy.nodes.items.len);
            if (src == dest or bitSet.isSet(src)) continue;
            try links.append(.{
                .dest = dest,
                .src = src,
                .weight = rng.floatNorm(f64),
                .op = rng.enumValue(Operation),
            });
        } else if (value == 2) {
            var link = copy.links.get(index);
            link.weight = rng.floatNorm(f64);
            copy.links.set(index, link);

            if (rng.weightedIndex(u64, &[_]u64{ learnRate, learnRate / 4 }) == 1) {
                link.op = rng.enumValue(Operation);
            }
        }
    }

    // Removing Links
    value = rng.weightedIndex(u64, &[_]u64{ 10, learnRate });
    i = 0;
    while (value == 1) : (i += 1) {
        copy.links.orderedRemove(rng.uintLessThan(usize, copy.links.len));
        value = rng.weightedIndex(u64, &[_]u64{ 10 + i, learnRate });
    }

    try copy.addLinks(links.items);

    return copy;
}
