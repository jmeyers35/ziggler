const std = @import("std");
const net = std.net;
const log = std.log;
const posix = std.posix;

const assert = std.debug.assert;

// IO implementation using the POSIX API.
// TODO: convert networking calls to use posix
pub const PosixIO = struct {
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

    pub fn init() !PosixIO {
        return .{ .tcp_conn = .{
            .conn = null,
            .open = false,
            .srv = undefined,
        } };
    }

    // Network operations
    pub fn accept(io: *PosixIO) !void {
        assert(io.tcp_conn.conn == null);
        assert(!io.tcp_conn.open);

        io.tcp_conn.conn = try io.tcp_conn.srv.accept();
        io.tcp_conn.open = true;
        log.info("establised connection: {any}\n", .{io.tcp_conn});
    }

    pub fn listen(io: *PosixIO, addr: net.Address) !void {
        io.tcp_conn.srv = try addr.listen(.{});
    }

    pub fn recv(io: *PosixIO, buf: []u8) !usize {
        assert(io.tcp_conn.open);
        assert(io.tcp_conn.conn != null);

        return io.tcp_conn.conn.?.stream.read(buf);
    }

    pub fn send(io: *PosixIO, bytes: []const u8) !void {
        assert(io.tcp_conn.open);
        assert(io.tcp_conn.conn != null);

        return io.tcp_conn.conn.?.stream.writeAll(bytes);
    }

    pub fn close_conn(io: *PosixIO) !void {
        assert(io.tcp_conn.open);
        assert(io.tcp_conn.conn != null);

        io.tcp_conn.conn.?.stream.close();
        io.tcp_conn.conn = null;
        io.tcp_conn.open = false;
    }

    // Disk operations
    pub const fd_t = posix.fd_t;

    // Opens the given _directory_ at the path provided.
    pub fn open_dir(_: *PosixIO, path: []const u8) !fd_t {
        assert(path.len > 0);
        const flags: posix.O = .{
            .ACCMODE = .RDONLY,
            .APPEND = true,
            .CREAT = true,
        };
        const fd = try posix.open(path, flags, 0);
        errdefer posix.close(fd);
        return fd;
    }

    pub fn open_data_file(_: *PosixIO, dirFD: fd_t, relativePath: []const u8) !fd_t {
        assert(relativePath.len > 0);
        const flags: posix.O = .{
            .ACCMODE = .RDWR,
            .APPEND = true,
            .CREAT = true,
        };
        const fd = try posix.openat(dirFD, relativePath, flags, 0o666);
        errdefer posix.close(fd);
        return fd;
    }

    pub fn close(_: *PosixIO, fd: fd_t) void {
        posix.close(fd);
    }

    pub fn deinit(io: *PosixIO) void {
        io.tcp_conn.deinit();
    }
};
