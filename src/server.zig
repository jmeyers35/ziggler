const std = @import("std");
const http = std.http;
const net = std.net;
const mem = std.mem;

const Address = net.Address;

pub const ServerOpts = struct {
    addr: Address,
    message: []const u8 = "hello, world",
};

pub const Server = struct {
    // Configured options
    addr: Address,
    message: []const u8 = "hello, world",

    pub fn init(opts: ServerOpts) !Server {
        return Server{
            .addr = opts.addr,
            .message = opts.message,
        };
    }

    // listen blocks on accepting a connection to the configured address
    pub fn listen(self: *Server) !void {
        var srv = try self.addr.listen(.{});
        defer srv.deinit();

        _ = try srv.accept();
    }
};
