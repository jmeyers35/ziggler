const std = @import("std");

// Uses a simple hashmap to keep string-string kv pairs
pub const InMemoryStore = struct {
    map: std.AutoArrayHashMap([]u8, []u8),
    alloc: std.mem.Allocator,

    pub fn init() @This() {
        const gpa = std.heap.GeneralPurposeAllocator(.{});
        return .{
            .alloc = gpa,
            .map = std.AutoHashMap([]u8, []u8).init(gpa),
        };
    }

    pub fn deinit(store: *InMemoryStore) void {
        store.map.deinit();
    }

    pub fn put(store: *InMemoryStore, key: []u8, value: []u8) !void {
        try store.map.put(key, value);
    }

    pub fn get(store: *InMemoryStore, key: []u8) ?[]u8 {
        return store.map.get(key);
    }
};
