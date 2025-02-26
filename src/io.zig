const std = @import("std");
const net = std.net;
const log = std.log;

const assert = std.debug.assert;

pub const IO = struct {
    srv: net.Server,
    conn: ?net.Server.Connection,
    open: bool,

    pub fn init(addr: net.Address) !IO {
        return .{ .srv = try addr.listen(.{}), .conn = null, .open = false };
    }

    pub fn accept(io: *IO) !void {
        assert(io.conn == null);
        assert(!io.open);

        io.conn = try io.srv.accept();
        log.info("establised connection: {any}\n", .{io.conn});
        io.open = true;
    }

    pub fn read(io: *IO, buf: []u8) !usize {
        assert(io.open);
        assert(io.conn != null);

        return io.conn.?.stream.read(buf);
    }

    pub fn close(io: *IO) !void {
        assert(io.open);
        assert(io.conn != null);

        io.conn.?.stream.close();
        io.conn = null;
        io.open = false;
    }

    pub fn deinit(io: *IO) void {
        io.srv.deinit();
    }
};
