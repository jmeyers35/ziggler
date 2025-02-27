const std = @import("std");
const log = std.log;

// TODO: pass address in here and let server configure the IO?
pub fn ServerType(comptime IOType: type, comptime StorageType: type) type {
    return struct {
        const Server = @This();
        // Configured options
        io: IOType,
        storage: StorageType,

        pub fn init(io: IOType, storage: StorageType) !Server {
            return .{
                .io = io,
                .storage = storage,
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
                        const lastStored = server.storage.get("foo") orelse "<none>";
                        log.info("last thing stored at foo: {s}\n", .{lastStored});
                        break;
                    }
                    log.info("read {d} bytes: {s}\n", .{ n, buf });
                    try server.storeBytes("foo", buf[0..n]);
                }
            }
        }

        fn storeBytes(server: *Server, key: []const u8, bytes: []const u8) !void {
            try server.storage.put(key, bytes);
        }
    };
}
