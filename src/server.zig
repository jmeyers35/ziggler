const std = @import("std");
const log = std.log;
const assert = std.debug.assert;
const protocol = @import("protocol.zig");
const Operation = protocol.Operation;

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
                    // TODO: handle connection reset errors, etc
                    const n = try server.io.read(&buf);
                    if (n == 0) {
                        log.info("connection closed", .{});
                        try server.io.close();
                        break;
                    }
                    log.debug("got request: {s} n:{d}", .{ buf[0..n], n });

                    // TODO: more graceful error handling
                    try server.handle_request(buf[0..n]);
                }
            }
        }

        fn handle_request(server: *Server, request: []const u8) !void {
            const parsed = protocol.parse_request(request) catch |err| {
                try server.io.send("Parse Error");
                log.err("error parsing request: {any}", .{err});
                return;
            };

            if (parsed.operation == Operation.get) {
                const got = server.storage.get(parsed.key) orelse "<null>";
                log.info("got value {s} for key {s}", .{ got, parsed.key });
                // TODO: gracefully handle nulls? how should we handle not found? check what Redis does
                try server.io.send(got);
            } else if (parsed.operation == Operation.set) {
                assert(parsed.value != null);
                const val = parsed.value.?;
                server.storage.set(parsed.key, val) catch |err| {
                    try server.io.send("Error"); // TODO: define errors in protocol
                    log.err("error writing to storage: {any}", .{err});
                    return;
                };
                log.info("set key {s} to {s}", .{ parsed.key, val });
                try server.io.send("OK");
            }
        }
    };
}
