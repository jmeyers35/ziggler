const std = @import("std");
const net = std.net;
const log = std.log;

const assert = std.debug.assert;

pub const IO = struct {
    const TCPConnection = struct {
        conn: ?net.Server.Connection,
        open: bool,
        srv: net.Server,

        fn deinit(conn: *TCPConnection) void {
            conn.srv.deinit();
            conn.srv = undefined;
            conn.open = false;
            conn.conn = null;
        }
    };

    tcp_conn: TCPConnection,

    pub fn init() !IO {
        return .{ .conn = .{
            .conn = null,
            .open = false,
            .srv = undefined,
        } };
    }

    // Network operations
    pub fn accept(io: *IO) !void {
        assert(io.tcp_conn.conn == null);
        assert(!io.tcp_conn.open);

        io.tcp_conn.conn = try io.tcp_conn.srv.accept();
        io.tcp_conn.open = true;
        log.info("establised connection: {any}\n", .{io.tcp_conn});
    }

    pub fn listen(io: *IO, addr: net.Address) !void {
        io.tcp_conn.srv = try addr.listen(.{});
    }

    pub fn recv(io: *IO, buf: []u8) !usize {
        assert(io.tcp_conn.open);
        assert(io.tcp_conn.conn != null);

        return io.tcp_conn.conn.?.stream.read(buf);
    }

    pub fn send(io: *IO, bytes: []const u8) !void {
        assert(io.tcp_conn.open);
        assert(io.tcp_conn.conn != null);

        return io.tcp_conn.conn.?.stream.writeAll(bytes);
    }

    pub fn close_conn(io: *IO) !void {
        assert(io.tcp_conn.open);
        assert(io.tcp_conn.conn != null);

        io.tcp_conn.conn.?.stream.close();
        io.tcp_conn.conn = null;
        io.tcp_conn.open = false;
    }

    pub fn deinit(io: *IO) void {
        io.tcp_conn.deinit();
    }
};
