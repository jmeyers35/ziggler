const std = @import("std");
const net = std.net;
const log = std.log;
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

        while (true) {
            const conn = try srv.accept();
            log.info("establised connection: {any}\n", .{conn});

            // TODO: bigger buffer? figure out how large single messages can be?
            // probably quite big if we handle arbitrarily-sized values
            var buf: [1024]u8 = undefined;
            while (true) {
                const n = try conn.stream.read(&buf);
                if (n == 0) {
                    log.info("connection closed", .{});
                    break;
                }
                log.info("read {d} bytes: {s}\n", .{ n, buf });
            }
        }
    }
};
