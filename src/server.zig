const std = @import("std");
const log = std.log;

// TODO: pass address in here and let server configure the IO?
pub fn ServerType(comptime IOType: type) type {
    return struct {
        const Server = @This();
        // Configured options
        io: IOType,

        pub fn init(io: IOType) !Server {
            return .{
                .io = io,
            };
        }

        // listen blocks on accepting a connection to the configured address
        pub fn listen(server: *Server) !void {
            while (true) {
                try server.io.accept();
                // TODO: bigger buffer? figure out how large single messages can be?
                // probably quite big if we handle arbitrarily-sized values
                var buf: [1024]u8 = undefined;

                while (true) {
                    const n = try server.io.read(&buf);
                    if (n == 0) {
                        log.info("connection closed", .{});
                        try server.io.close();
                        break;
                    }
                    log.info("read {d} bytes: {s}\n", .{ n, buf });
                }
            }
        }
    };
}
