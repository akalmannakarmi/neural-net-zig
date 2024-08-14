const std = @import("std");
const Link = @import("structs.zig").Link;
const Operation = @import("structs.zig").Operation;
const NeuralNet = @import("ai.zig").NeuralNet;
const Random = std.Random;

var rng = Random.DefaultPrng.init(0).random();

const Self = @This();
nn: NeuralNet,

pub fn init(alloc: std.mem.Allocator) Self {
    return Self{
        .nn = NeuralNet.init(alloc),
    };
}
pub fn deinit(self: *Self) void {
    self.nn.deinit();
}

pub fn createRandom(self: *Self, input: u64, output: u64, temp: u64, mem: u64) !void {
    const totalNodes = input + temp + mem + output;
    const links = std.ArrayList(Link).init(self.nn.allocator);
    const nodes = std.ArrayList(u64).init(self.nn.allocator);
    const bitSet = try std.DynamicBitSet.initEmpty(self.nn.allocator, totalNodes);
    nodes.ensureTotalCapacity(totalNodes);

    for (totalNodes..totalNodes + output) |out| {
        nodes.append(out);
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
            links.append(.{
                .dest = dest,
                .src = src,
                .weight = rng.floatNorm(f64),
                .op = rng.enumValue(Operation),
            });
            nodes.appendAssumeCapacity(src);
            const value = rng.weightedIndex(u64, []u64{ 10, i });
            if (value == 1) {
                nodes.orderedRemove(index);
                index -= 1;
            }
        }
    }
    try self.nn.create(input, output, temp, mem, links.items);
}

pub fn createRnCopy(self: *Self, learnRate: u64) !Self {
    const copy = Self{
        .nn = self.nn.clone(),
    };

    // Adding Nodes
    const value = rng.weightedIndex(u64, []u64{ 10, learnRate });
    if (value == 1) {
        self.nn.addNodes(0, 0, rng.uintLessThan(u64, 10), rng.uintLessThan(u64, 10));
    }

    // Adding/Updating Links
    const links = std.ArrayList(Link).init(self.nn.allocator);
    const bitSet = try std.DynamicBitSet.initEmpty(self.nn.allocator, self.nn.nodes.items.len);

    const linksSlice = self.nn.links.slice();
    const dests: []u64 = linksSlice.items(.dest);
    for (dests, 0..) |dest, i| {
        bitSet.set(dest);
        const v = rng.weightedIndex(u64, []u64{ 10 + links.items.len, learnRate / 2, learnRate });
        if (v == 1) {
            const src = rng.uintLessThan(u64, self.nn.nodes.items.len);
            if (src == dest or bitSet.isSet(src)) continue;
            links.append(.{
                .dest = dest,
                .src = src,
                .weight = rng.floatNorm(f64),
                .op = rng.enumValue(Operation),
            });
        } else if (v == 2) {
            const link = self.nn.links.get(i);
            link.weight = rng.floatNorm(f64);

            if (rng.weightedIndex(u64, []u64{ learnRate, learnRate / 4 }) == 1) {
                link.op = rng.enumValue(Operation);
            }
        }
    }

    // Removing Links
    var value_ = rng.weightedIndex(u64, []u64{ 10, learnRate });
    var i = 0;
    while (value_ == 1) : (i += 1) {
        self.nn.links.orderedRemove(rng.uintLessThan(usize, self.nn.links.len));
        value_ = rng.weightedIndex(u64, []u64{ 10 + i, learnRate });
    }

    try self.nn.addLinks(links.items);

    return copy;
}
