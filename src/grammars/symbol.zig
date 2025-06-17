pub const Symbol = struct {
    name: []const u8,

    /// Create a new symbol from an arbitrary string.
    pub fn from(name: []const u8) Symbol {
        return Symbol{ .name = name };
    }
};
