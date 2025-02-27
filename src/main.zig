const std = @import("std");
const log = std.log;
const server = @import("server.zig");
const io = @import("io.zig");
const kv = @import("kv.zig");

pub fn main() !void {
    // get a server
    const addr = try std.net.Address.resolveIp("127.0.0.1", 8080);
    var netIO = try io.IO.init(addr);
    defer netIO.deinit();
    var alloc = std.heap.GeneralPurposeAllocator(.{}){};
    var memStorage = kv.InMemoryStore.init(alloc.allocator());
    defer memStorage.deinit();
    var srv = try server.ServerType(io.IO, kv.InMemoryStore).init(netIO, memStorage);
    log.info("starting ziggler server", .{});
    try srv.listen();
}
