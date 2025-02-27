const std = @import("std");
const log = std.log;
const mem = std.mem;

// Uses a simple hashmap to keep string-string kv pairs
pub const InMemoryStore = struct {
    map: std.StringArrayHashMap([]const u8),
    alloc: mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) @This() {
        return .{
            .map = std.StringArrayHashMap([]const u8).init(alloc),
            .alloc = alloc,
        };
    }

    pub fn deinit(store: *InMemoryStore) void {
        store.map.deinit();
    }

    pub fn set(store: *InMemoryStore, key: []const u8, value: []const u8) !void {
        const key_copy = try store.alloc.dupe(u8, key);
        const value_copy = try store.alloc.dupe(u8, value);
        try store.map.put(key_copy, value_copy);
    }

    pub fn get(store: *InMemoryStore, key: []const u8) ?[]const u8 {
        return store.map.get(key);
    }
};

const testing = std.testing;
const expect = testing.expect;
const expectEqualStrings = testing.expectEqualStrings;

test "basic functionality" {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .verbose_log = true,
    }){};
    const alloc = gpa.allocator();
    var kv = InMemoryStore.init(alloc);
    defer kv.deinit();

    // zig learning time - if this call fails, the entire test will fail
    try kv.set("hello", "world");

    const got = kv.get("hello");

    try expect(got != null);
    try expectEqualStrings("world", got.?);

    // value that's not there
    const gotNotThere = kv.get("foobar");
    try expect(gotNotThere == null);
}
