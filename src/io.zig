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
        };
        const fd = try posix.open(path, flags, 0);
        errdefer posix.close(fd);
        return fd;
    }

    pub fn open_data_file(_: *PosixIO, dirFD: fd_t, relativePath: []const u8) !fd_t {
        assert(relativePath.len > 0);
        // c.f. tigerbeetle
        // Be careful with openat(2): "If pathname is absolute, then dirfd is ignored." (man page)
        assert(!std.fs.path.isAbsolute(relativePath));

        const flags: posix.O = .{
            .ACCMODE = .RDWR,
            .APPEND = true,
            .CREAT = true,
            .DSYNC = true, // c.f. tigerbeetle: src/io/darwin.zig. i'll have to figure out later if i actually want to support mac or just do linux. apparently this flag is crucial for fsync.
        };
        const fd = try posix.openat(dirFD, relativePath, flags, 0o666);
        errdefer posix.close(fd);
        return fd;
    }

    pub fn close(_: *PosixIO, fd: fd_t) void {
        posix.close(fd);
    }

    pub fn write(_: *PosixIO, fd: fd_t, bytes: []const u8) !usize {
        // TODO: better error handling?
        const n = try posix.write(fd, bytes);
        // Just assume we do indeed want all disk writes fully fsync'd every time for now.
        try fs_sync(fd);
        return n;
    }

    // c.f. tigerbeetle
    fn fs_sync(fd: fd_t) !void {
        // TODO: This is of dubious safety - it's _not_ safe to fall back on posix.fsync unless it's
        // known at startup that the disk (eg, an external disk on a Mac) doesn't support
        // F_FULLFSYNC.
        _ = posix.fcntl(fd, posix.F.FULLFSYNC, 1) catch return posix.fsync(fd);
    }

    pub fn read(_: *PosixIO, fd: fd_t, buf: []u8, offset: u64) !usize {
        return posix.pread(fd, buf, offset);
    }

    pub fn deinit(io: *PosixIO) void {
        io.tcp_conn.deinit();
    }
};
