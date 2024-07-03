const std = @import("std");

const allocator = std.heap.page_allocator;
const rng = std.rand.DefaultPrng.init(0);

const Operations = enum(u32) {
    addition,
    substract,
    product,
    division,
    modulus,
    power,
    AND,
    OR,
    XOR,
    NOT,
    LEFT,
    RIGHT,
    positive,
    negative,
    not,
};
const Conditions = enum(u8) {
    none,
    isEqual,
    isNotEqual,
    isGreater,
    isLess,
    isGreaterOrEqual,
    isLessOrEqual,
};
const Weight = union(enum) {
	neuron:u64,
	float:f64,
	int:u64, 
};
const Connection = struct {
    input: u64,
    output: u64,
    weight: Weight,
    operation: Operations,
    conditions: Conditions,
    pub fn calculate(self: *const Connection) !void {
        switch (self.operation) {
            0 => {},
        }
    }
};

fn compareConnection(a: Connection, b: Connection) std.sort.Order {
    if (a.input < b.input) {
        return std.sort.Order.less;
    } else if (a.input > b.input) {
        return std.sort.Order.greater;
    } else if (a.output < b.output) {
        return std.sort.Order.less;
    } else if (a.output > b.output) {
        return std.sort.Order.greater;
    } else {
        return std.sort.Order.equal;
    }
}

const neurons = std.ArrayList(f64).init(allocator);
const connections = std.ArrayList(Connection).init(allocator);

pub fn resetNeurons() !void {
    for (0..neurons.items.len) |i| {
        neurons.items[i] = 0;
    }
}

pub fn newNeurons(n: u64) !u64 {
    for (0..n) |_| {
        try neurons.append(0);
    }
    return neurons.items.len - n;
}

pub fn removeNeuron(index: u64) !void {
    var i: usize = connections.items.len;
    while (i > 0) : (i -= 1) {
        if (connections.items[i].input == index) {
            connections.orderedRemove(i);
        } else if (connections.items[i].output == index) {
            connections.orderedRemove(i);
        }

        if (connections.items[i].input > index) {
            connections.items[i].input -= 1;
        }
        if (connections.items[i].output > index) {
            connections.items[i].output -= 1;
        }
    }
    try neurons.orderedRemove(index);
}

pub fn newConnection(inputIndex: u64, outputIndex: u64, weight: u64) !void {
    const newConn = .{
        .input = inputIndex,
        .output = outputIndex,
        .weight = weight,
    };
    try connections.ensureTotalCapacity(connections.items.len + 1);
    std.sort.insertion(Connection, connections.items, newConn, compareConnection);
    const index = std.sort.binarySearch(Connection, connections.items, newConn, compareConnection);

    if (index) {
        connections.items[index].weight = weight;
    } else {
        try connections.insert(index, newConn);
    }
}

pub fn removeConnection(inputIndex: u64, outputIndex: u64) !void {
    const targetConn = .{
        .input = inputIndex,
        .output = outputIndex,
        .weight = 0,
    };

    const index = std.sort.binarySearch(Connection, connections.items, targetConn, compareConnection);

    if (index) |i| {
        connections.orderedRemove(i);
    }
}
