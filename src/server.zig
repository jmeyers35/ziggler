const std = @import("std");
const fmt = std.fmt;
const log = std.log;
const mem = std.mem;
const net = std.net;

const assert = std.debug.assert;

const protocol = @import("protocol.zig");
const Operation = protocol.Operation;

const constants = @import("constants.zig");

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
                var buf: [2048]u8 = undefined;
                while (true) {
                    // TODO: handle connection reset errors, etc
                    const n = try server.io.recv(&buf);
                    if (n == 0) {
                        log.info("connection closed", .{});
                        try server.io.close_conn();
                        break;
                    }
                    try server.handle_request(buf[0..n]);
                }
            }
        }

        fn handle_request(server: *Server, request: []const u8) !void {
            const parsed = protocol.parse_request(request) catch |err| {
                // TODO: do better than this
                const resp = protocol.Response{ .Error = "parse error" };
                const serialized = protocol.Response.serialize(resp);
                try server.io.send(serialized.data[0..serialized.len]);
                log.err("error parsing request: {any}", .{err});
                return;
            };

            assert(parsed.key.len <= constants.VALUE_SIZE_MIN);

            var serialized_response: protocol.SerializedResponse = undefined;

            if (parsed.operation == Operation.get) {
                const got = server.storage.get(parsed.key) orelse "<null>";
                assert(got.len <= constants.VALUE_SIZE_MAX);
                serialized_response = protocol.Response.serialize(protocol.Response{ .Data = got });
            } else if (parsed.operation == Operation.set) {
                assert(parsed.value != null);
                const val = parsed.value.?;
                assert(val.len <= constants.VALUE_SIZE_MAX);
                server.storage.set(parsed.key, val) catch |err| {
                    const resp = protocol.Response{ .Error = "persist error" };
                    const serialized = protocol.Response.serialize(resp);
                    try server.io.send(serialized.data[0..serialized.len]);
                    log.err("error writing to storage: {any}", .{err});
                    return;
                };
                serialized_response = protocol.Response.serialize(protocol.Response.Ok);
            }
            try server.io.send(serialized_response.data[0..serialized_response.len]);
        }
    };
}
