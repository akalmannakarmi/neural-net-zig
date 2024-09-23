pub const Link = struct {
    src: u64,
    dest: u64,
    weight: f64,
    op: Operation,
};

pub const Operation = enum(u8) {
    addition,
    subtraction,
    multiplication,
};
