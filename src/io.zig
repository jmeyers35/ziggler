const std = @import("std");
const net = std.net;
const log = std.log;

const assert = std.debug.assert;

pub const IO = struct {
    const Connection = struct {
        conn: ?net.Server.Connection,
        open: bool,
        srv: net.Server,

        fn deinit(conn: *Connection) void {
            conn.srv.deinit();
            conn.srv = undefined;
            conn.open = false;
            conn.conn = null;
        }
    };

    // TODO: fix stutter
    conn: Connection,

    pub fn init() !IO {
        return .{ .conn = .{
            .conn = null,
            .open = false,
            .srv = undefined,
        } };
    }

    // Network operations
    pub fn accept(io: *IO) !void {
        assert(io.conn.conn == null);
        assert(!io.conn.open);

        io.conn.conn = try io.conn.srv.accept();
        io.conn.open = true;
        log.info("establised connection: {any}\n", .{io.conn});
    }

    pub fn listen(io: *IO, addr: net.Address) !void {
        io.conn.srv = try addr.listen(.{});
    }

    pub fn recv(io: *IO, buf: []u8) !usize {
        assert(io.conn.open);
        assert(io.conn.conn != null);

        return io.conn.conn.?.stream.read(buf);
    }

    pub fn send(io: *IO, bytes: []const u8) !void {
        assert(io.conn.open);
        assert(io.conn.conn != null);

        return io.conn.conn.?.stream.writeAll(bytes);
    }

    pub fn close_conn(io: *IO) !void {
        assert(io.conn.open);
        assert(io.conn.conn != null);

        io.conn.conn.?.stream.close();
        io.conn.conn = null;
        io.conn.open = false;
    }

    pub fn deinit(io: *IO) void {
        io.conn.deinit();
    }
};
