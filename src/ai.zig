const std = @import("std");
const Link = @import("structs.zig").Link;
const Operation = @import("structs.zig").Operation;

pub const NeuralNet = struct {
    inputNodes: u64,
    tempNodes: u64,
    memNodes: u64,
    outputNodes: u64,
    allocator: std.mem.Allocator,
    nodes: std.ArrayList(f64),
    links: std.MultiArrayList(Link),

    pub fn init(alloc: std.mem.Allocator) NeuralNet {
        return .{
            .inputNodes = 0,
            .tempNodes = 0,
            .memNodes = 0,
            .outputNodes = 0,
            .allocator = alloc,
            .nodes = std.ArrayList(f64).init(alloc),
            .links = std.MultiArrayList(Link){},
        };
    }
    pub fn deinit(self: *NeuralNet) void {
        self.nodes.deinit();
        self.links.deinit(self.allocator);
    }

    pub fn load(self: *NeuralNet, filename: []const u8) !void {
        const file = try std.fs.cwd().openFile(filename, .{ .mode = .read_only, .lock = .shared });
        defer file.close();
        const reader = file.reader();

        // reading no of Nodes & Links
        self.inputNodes = try reader.readInt(u64, .big);
        self.tempNodes = try reader.readInt(u64, .big);
        self.memNodes = try reader.readInt(u64, .big);
        self.outputNodes = try reader.readInt(u64, .big);
        const noLinks = try reader.readInt(u64, .big);

        // Creating Space for Nodes & Links
        const totalNodes = self.inputNodes + self.tempNodes + self.memNodes + self.outputNodes;
        try self.nodes.resize(totalNodes);
        try self.links.resize(self.allocator, noLinks);

        // Load Memory Nodes
        @memset(self.nodes.items, 0);
        const memNodeSlice = self.nodes.items[self.inputNodes + self.tempNodes .. totalNodes - self.outputNodes];
        _ = try reader.read(std.mem.sliceAsBytes(memNodeSlice));

        // Load Links
        const linkSlice = self.links.slice();

        _ = try reader.read(std.mem.sliceAsBytes(linkSlice.items(.src)));
        _ = try reader.read(std.mem.sliceAsBytes(linkSlice.items(.dest)));
        _ = try reader.read(std.mem.sliceAsBytes(linkSlice.items(.weight)));
        _ = try reader.read(std.mem.sliceAsBytes(linkSlice.items(.op)));
    }
    pub fn save(self: *NeuralNet, filename: []const u8) !void {
        const file = try std.fs.cwd().createFile(filename, .{ .lock = .exclusive });
        defer file.close();
        const writer = file.writer();

        // Writing No of Nodes and Links
        try writer.writeInt(u64, self.inputNodes, .big);
        try writer.writeInt(u64, self.tempNodes, .big);
        try writer.writeInt(u64, self.memNodes, .big);
        try writer.writeInt(u64, self.outputNodes, .big);
        try writer.writeInt(u64, @as(u64, self.links.len), .big);

        // Saving Memory Nodes
        const memNodeSlice = self.nodes.items[self.inputNodes + self.tempNodes .. self.nodes.items.len - self.outputNodes];
        _ = try writer.write(std.mem.sliceAsBytes(memNodeSlice));

        // Saving Links
        const linkSlice = self.links.slice();

        _ = try writer.write(std.mem.sliceAsBytes(linkSlice.items(.src)));
        _ = try writer.write(std.mem.sliceAsBytes(linkSlice.items(.dest)));
        _ = try writer.write(std.mem.sliceAsBytes(linkSlice.items(.weight)));
        _ = try writer.write(std.mem.sliceAsBytes(linkSlice.items(.op)));
    }

    pub fn setInputs(self: *NeuralNet, inputs: []f64) void {
        for (inputs, 0..) |input, index| {
            self.nodes.items[index] = input;
            if (index >= self.inputNodes) return;
        }
    }
    pub fn getOutputs(self: *NeuralNet) []f64 {
        return self.nodes.items[self.nodes.items.len - self.outputNodes ..];
    }
    pub fn process(self: *NeuralNet) void {
        const nodes = self.nodes.items;
        const linksSlice = self.links.slice();
        const srcs: []u64 = linksSlice.items(.src);
        const dests: []u64 = linksSlice.items(.dest);
        const weights: []f64 = linksSlice.items(.weight);
        const ops: []Operation = linksSlice.items(.op);

        // Reset Temp Nodes
        @memset(self.nodes.items[self.inputNodes .. self.inputNodes + self.tempNodes], 0);

        // Execute Links
        for (srcs, dests, weights, ops) |src, dest, weight, op| {
            switch (op) {
                .addition => {
                    nodes[dest] += nodes[src] * weight;
                },
                .subtraction => {
                    nodes[dest] -= nodes[src] * weight;
                },
                .multiplication => {
                    nodes[dest] *= nodes[src] * weight;
                },
                .division => {
                    nodes[dest] /= nodes[src] * weight;
                },
            }
        }
    }

    pub fn create(self: *NeuralNet, inputNodes: u64, outputNodes: u64, tempNodes: u64, memNodes: u64, links: []const Link) !void {
        self.inputNodes = inputNodes;
        self.tempNodes = tempNodes;
        self.memNodes = memNodes;
        self.outputNodes = outputNodes;
        const totalNodes = inputNodes + tempNodes + memNodes + outputNodes;
        try self.nodes.resize(totalNodes);
        try self.links.resize(self.allocator, links.len);
        try self.addLinks(links);
    }
    pub fn addNodes(self: *NeuralNet, inputNodes: u64, outputNodes: u64, tempNodes: u64, memNodes: u64) !void {
        const totalNodes = inputNodes + outputNodes + tempNodes + memNodes + self.inputNodes + self.outputNodes + self.tempNodes + self.memNodes;
        try self.nodes.ensureUnusedCapacity(totalNodes);

        var addIndex = self.inputNodes;
        var newSlice = self.nodes.addManyAtAssumeCapacity(addIndex, inputNodes);
        self.adjustLinks(addIndex, inputNodes);
        @memset(newSlice, 0);

        addIndex += inputNodes + self.tempNodes;
        newSlice = self.nodes.addManyAtAssumeCapacity(addIndex, tempNodes);
        self.adjustLinks(addIndex, tempNodes);
        @memset(newSlice, 0);

        addIndex += tempNodes + self.memNodes;
        newSlice = self.nodes.addManyAtAssumeCapacity(addIndex, memNodes);
        self.adjustLinks(addIndex, memNodes);
        @memset(newSlice, 0);

        addIndex += memNodes + self.outputNodes;
        newSlice = self.nodes.addManyAtAssumeCapacity(addIndex, outputNodes);
        self.adjustLinks(addIndex, outputNodes);
        @memset(newSlice, 0);

        self.inputNodes += inputNodes;
        self.tempNodes += tempNodes;
        self.memNodes += memNodes;
        self.outputNodes += outputNodes;
    }
    fn adjustLinks(self: *NeuralNet, index: u64, count: u64) void {
        const linkSlice = self.links.slice();
        const srcs: []u64 = linkSlice.items(.src);
        const dests: []u64 = linkSlice.items(.dest);
        for (srcs, dests) |*src, *dest| {
            if (src.* >= index) {
                src.* += count;
            }
            if (dest.* >= index) {
                dest.* += count;
            }
        }
    }
    pub fn deleteNode(self: *NeuralNet, index: u64) void {
        const lastIndex = self.nodes.items.len - 1;
        self.nodes.swapRemove(index);

        const linkSlice = self.links.slice();
        const srcs: []u64 = linkSlice.items(.src);
        const dests: []u64 = linkSlice.items(.dest);
        for (srcs, dests, 0..) |*src, *dest, i| {
            if (src.* == index) {
                self.deleteLink(i);
            } else if (dest.* == index) {
                self.deleteLink(i);
            } else {
                if (src.* == lastIndex) {
                    src.* == index;
                }
                if (dest.* == lastIndex) {
                    dest.* == index;
                }
            }
        }
    }
    pub fn setNode(self: *NeuralNet, index: u64, value: f64) void {
        self.nodes.items[index] = value;
    }
    pub fn addLinks(self: *NeuralNet, links: []Link) !void {
        self.links.ensureUnusedCapacity(self.allocator, links.len);

        for (links) |link| {
            const linksSlice = self.links.slice();
            const srcs: []u64 = linksSlice.items(.src);

            if (link.dest > self.nodes.items.len - self.outputNodes and link.dest < self.nodes.items.len) {
                self.links.insertAssumeCapacity(0, link);
                continue;
            }

            var i = srcs.len;
            while (i >= 0) : (i -= 1) {
                if (srcs[i] == link.dest) {
                    self.links.insertAssumeCapacity(i + 1, link);
                    continue;
                }
            }
            return error.CantNotInsert;
        }
    }
    pub fn deleteLink(self: *NeuralNet, index: u64) void {
        self.links.orderedRemove(index);
    }
    pub fn setLink(self: *NeuralNet, index: u64, weight: f64, op: Operation) void {
        const slice = self.links.slice();
        const weights: []f64 = slice.items(.wieght);
        const ops: []Operation = slice.items(.op);
        weights[index] = weight;
        ops[index] = op;
    }

    pub fn clone(self: *NeuralNet) !NeuralNet {
        return NeuralNet{
            .inputNodes = self.inputNodes,
            .tempNodes = self.tempNodes,
            .memNodes = self.memNodes,
            .outputNodes = self.outputNodes,
            .allocator = self.allocator,
            .nodes = try self.nodes.clone(),
            .links = try self.links.clone(self.allocator),
        };
    }
};
