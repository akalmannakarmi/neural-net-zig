const std = @import("std");
const Link = @import("structs.zig").Link;
const Operation = @import("structs.zig").Operation;

pub const NeuralNet = struct {
    inputNodes: u64,
    outputNodes: u64,
    tempNodes: u64,
    memNodes: u64,
    noLinks: u64,
    allocator: std.mem.Allocator,
    nodes: std.ArrayList(f64),
    links: std.MultiArrayList(Link),

    pub fn init(alloc: std.mem.Allocator) NeuralNet {
        return .{
            .inputNodes = 0,
            .outputNodes = 0,
            .tempNodes = 0,
            .memNodes = 0,
            .noLinks = 0,
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
        self.outputNodes = try reader.readInt(u64, .big);
        self.tempNodes = try reader.readInt(u64, .big);
        self.memNodes = try reader.readInt(u64, .big);
        self.noLinks = try reader.readInt(u64, .big);

        // Creating Space for Nodes & Links
        const totalNodes = self.inputNodes + self.outputNodes + self.tempNodes + self.memNodes;
        try self.nodes.resize(totalNodes);
        try self.links.resize(self.allocator, self.noLinks);

        // Load Memory Nodes
        @memset(self.nodes.items[0 .. totalNodes - self.memNodes], 0);
        const memNodeSlice = self.nodes.items[totalNodes - self.memNodes ..];
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
        try writer.writeInt(u64, self.outputNodes, .big);
        try writer.writeInt(u64, self.tempNodes, .big);
        try writer.writeInt(u64, self.memNodes, .big);
        try writer.writeInt(u64, self.noLinks, .big);

        // Saving Memory Nodes
        const memNodeSlice = self.nodes.items[self.nodes.items.len - self.memNodes ..];
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
        return self.nodes.items[self.inputNodes .. self.inputNodes + self.outputNodes];
    }

    pub fn process(self: *NeuralNet) void {
        const totalNodes = self.inputNodes + self.outputNodes + self.tempNodes + self.memNodes;

        // Reset Temp Nodes
        @memset(self.nodes.items[self.inputNodes + self.outputNodes .. totalNodes - self.memNodes], 0);

        // Execute Memory Nodes
        for (totalNodes - self.memNodes..totalNodes) |i| {
            try self.execute(i);
        }

        // Execute Input Nodes
        for (0..self.inputNodes) |i| {
            try self.execute(i);
        }
    }
    fn execute(self: *NeuralNet, nodeIndex: u64) !void {
        const stack = std.ArrayList(usize).init(self.allocator);
        defer stack.deinit();

        const nodes = self.nodes.items;
        const linksSlice = self.links.slice();
        const srcs: []u64 = linksSlice.items(.src);
        const dests: []u64 = linksSlice.items(.dest);
        const weights: []f64 = linksSlice.items(.weight);
        const ops: []Operation = linksSlice.items(.op);

        try stack.append(nodeIndex);
        while (stack.len > 0) {
            const current = stack.pop();

            for (srcs, 0..) |src, i| {
                if (src == current) {
                    try stack.append(dests[i]);
                    switch (ops[i]) {
                        .addition => {
                            nodes[dests[i]] += src * weights[i];
                        },
                        .subtraction => {
                            nodes[dests[i]] -= src * weights[i];
                        },
                        .multiplication => {
                            nodes[dests[i]] *= src * weights[i];
                        },
                        .division => {
                            nodes[dests[i]] /= src * weights[i];
                        },
                    }
                }
            }
        }
    }

    pub fn create(self: *NeuralNet, inputNodes: u64, outputNodes: u64, tempNodes: u64, memNodes: u64, links: []Link) !void {
        self.inputNodes = inputNodes;
        self.outputNodes = outputNodes;
        self.tempNodes = tempNodes;
        self.memNodes = memNodes;
        const totalNodes = inputNodes + outputNodes + tempNodes + memNodes;
        try self.nodes.resize(totalNodes);
        try self.links.resize(self.allocator, links.len);

        for (links, 0..) |link, i| {
            self.links.set(i, link);
        }
    }
    pub fn addNodes(self: *NeuralNet, inputNodes: u64, outputNodes: u64, tempNodes: u64, memNodes: u64) !void {
        const totalNodes = inputNodes + outputNodes + tempNodes + memNodes + self.inputNodes + self.outputNodes + self.tempNodes + self.memNodes;
        try self.nodes.ensureUnusedCapacity(totalNodes);

        var addIndex = self.inputNodes;
        var newSlice = self.nodes.addManyAtAssumeCapacity(addIndex, inputNodes);
        self.adjustLinks(addIndex, inputNodes);
        @memset(newSlice, 0);

        addIndex += inputNodes + self.outputNodes;
        newSlice = self.nodes.addManyAtAssumeCapacity(addIndex, outputNodes);
        self.adjustLinks(addIndex, outputNodes);
        @memset(newSlice, 0);

        addIndex += outputNodes + self.tempNodes;
        newSlice = self.nodes.addManyAtAssumeCapacity(addIndex, tempNodes);
        self.adjustLinks(addIndex, tempNodes);
        @memset(newSlice, 0);

        addIndex += tempNodes + self.memNodes;
        newSlice = self.nodes.addManyAtAssumeCapacity(addIndex, memNodes);
        self.adjustLinks(addIndex, memNodes);
        @memset(newSlice, 0);

        self.inputNodes += inputNodes;
        self.outputNodes += outputNodes;
        self.tempNodes += tempNodes;
        self.memNodes += memNodes;
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
        try self.links.ensureUnusedCapacity(self.allocator, links.len);
        self.noLinks += links.len;
        for (links) |link| {
            self.links.appendAssumeCapacity(link);
        }
    }
    pub fn deleteLink(self: *NeuralNet, index: u64) void {
        self.links.swapRemove(index);
        self.noLinks -= 1;
    }
    pub fn setLink(self: *NeuralNet, index: u64, weight: f64, op: Operation) void {
        const slice = self.links.slice();
        const weights: []f64 = slice.items(.wieght);
        const ops: []Operation = slice.items(.op);
        weights[index] = weight;
        ops[index] = op;
    }
};
