const std = @import("std");
const fmt = std.fmt;
const log = std.log;
const mem = std.mem;
const net = std.net;

const assert = std.debug.assert;

const protocol = @import("protocol.zig");
const Operation = protocol.Operation;

const constants = @import("constants.zig");

// TODO: pass address in here and let server configure the IO?
pub fn ServerType(comptime IOType: type, comptime StorageType: type) type {
    return struct {
        const Server = @This();
        // Configured options
        io: IOType,
        storage: StorageType,
        listen_addr: net.Address,

        pub fn init(io: IOType, storage: StorageType, listen_addr: net.Address) !Server {
            return .{
                .io = io,
                .storage = storage,
                .listen_addr = listen_addr,
            };
        }

        // listen blocks on accepting a connection to the configured address
        pub fn listen(server: *Server) !void {
            try server.io.listen(server.listen_addr);
            while (true) {
                try server.io.accept();
                // TODO: bigger buffer? figure out how large single messages can be?
                // probably quite big if we handle arbitrarily-sized values
                var buf: [1024]u8 = undefined;

                while (true) {
                    // TODO: handle connection reset errors, etc
                    const n = try server.io.recv(&buf);
                    if (n == 0) {
                        log.info("connection closed", .{});
                        try server.io.close_conn();
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
                // TODO: do better than this
                try server.io.send("Parse Error\r\n");
                log.err("error parsing request: {any}", .{err});
                return;
            };
            if (parsed.operation == Operation.get) {
                const got = server.storage.get(parsed.key) orelse "<null>";
                // TODO: figure out constraints around value sizes? we probably
                // can't get away with static allocations here forever (or can we?)
                // for now: we'll assert values are 1K or smaller
                // maybe we'll go after very small keys and values, predictable performance
                assert(got.len <= constants.MAX_VALUE_SIZE);
                var buf: [1026]u8 = undefined;
                mem.copyForwards(u8, buf[0..got.len], got);
                buf[got.len] = '\r';
                buf[got.len + 1] = '\n';
                try server.io.send(buf[0 .. got.len + 2]);
            } else if (parsed.operation == Operation.set) {
                // TODO: probably move these assertions to the parsing layer
                if (parsed.key.len > constants.MAX_VALUE_SIZE) {
                    try server.io.send("Error\r\n");
                    log.err("key too large: {d}", .{parsed.key.len});
                    return;
                }
                assert(parsed.value != null);
                const val = parsed.value.?;
                if (val.len > constants.MAX_VALUE_SIZE) {
                    try server.io.send("Error\r\n");
                    log.err("value too large: {d}", .{val.len});
                    return;
                }
                server.storage.set(parsed.key, val) catch |err| {
                    try server.io.send("Error\r\n"); // TODO: define errors in protocol
                    log.err("error writing to storage: {any}", .{err});
                    return;
                };
                try server.io.send("OK\r\n");
            }
        }
    };
}
