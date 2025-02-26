const std = @import("std");
const log = std.log;
const server = @import("server.zig");

pub fn main() !void {
    // get a server
    const addr = try std.net.Address.resolveIp("127.0.0.1", 8080);
    const opts = server.ServerOpts{
        .addr = addr,
        .message = "hello, jacob",
    };
    var srv = try server.Server.init(opts);
    log.info("starting ziggler server", .{});
    try srv.listen();
}
