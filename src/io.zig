const std = @import("std");
const net = std.net;
const log = std.log;
const posix = std.posix;
const mem = std.mem;

const assert = std.debug.assert;

// IO implementation using the POSIX API.
// TODO: convert networking calls to use posix
pub const PosixIO = struct {
    pub fn init() !PosixIO {
        return .{};
    }

    // Network operations
    pub const socket_t = posix.socket_t;

    pub fn accept(io: *PosixIO, fd: socket_t) !socket_t {
        const conn_fd = try posix.accept(fd, null, null, 0);
        errdefer io.close_socket(conn_fd);
        try posix.setsockopt(conn_fd, posix.SOL.SOCKET, posix.SO.NOSIGPIPE, &mem.toBytes(@as(c_int, 1)));
        return conn_fd;
    }

    pub fn open_socket(io: *PosixIO, domain: u32, socket_type: u32, protocol: u32) !socket_t {
        const fd = try posix.socket(domain, socket_type, protocol);
        errdefer io.close_socket(fd);
        try posix.setsockopt(fd, posix.SOL.SOCKET, posix.SO.NOSIGPIPE, &mem.toBytes(@as(c_int, 1)));
        return fd;
    }

    pub fn close_socket(io: *PosixIO, fd: socket_t) void {
        _ = io;
        posix.close(fd);
    }

    pub fn listen(io: *PosixIO, fd: socket_t, addr: *net.Address) !void {
        _ = io;
        var sock_len = addr.getOsSockLen();
        try posix.setsockopt(fd, posix.SOL.SOCKET, posix.SO.REUSEADDR, &mem.toBytes(@as(c_int, 1)));
        try posix.bind(fd, &addr.any, sock_len);
        try posix.listen(fd, 128);
        try posix.getsockname(fd, &addr.any, &sock_len);
    }

    pub fn recv(io: *PosixIO, fd: socket_t, buf: []u8) !usize {
        _ = io;
        const n = posix.recv(fd, buf, 0) catch |err| {
            switch (err) {
                posix.RecvFromError.ConnectionResetByPeer => return 0,
                else => return err,
            }
        };
        return n;
    }

    pub fn send(io: *PosixIO, fd: socket_t, bytes: []const u8) !void {
        _ = io;
        _ = try posix.send(fd, bytes, 0);
    }

    // Disk operations
    pub const fd_t = posix.fd_t;

    // Opens the given _directory_ at the path provided.
    pub fn open_dir(io: *PosixIO, path: []const u8) !fd_t {
        _ = io;
        assert(path.len > 0);
        const flags: posix.O = .{
            .ACCMODE = .RDONLY,
        };
        const fd = try posix.open(path, flags, 0);
        errdefer posix.close(fd);
        return fd;
    }

    pub fn open_data_file(io: *PosixIO, dir_fd: fd_t, relative_path: []const u8) !fd_t {
        _ = io;
        assert(relative_path.len > 0);
        // c.f. tigerbeetle
        // Be careful with openat(2): "If pathname is absolute, then dirfd is ignored." (man page)
        assert(!std.fs.path.isAbsolute(relative_path));

        const flags: posix.O = .{
            .ACCMODE = .RDWR,
            .APPEND = true,
            .CREAT = true,
            .DSYNC = true, // c.f. tigerbeetle: src/io/darwin.zig. i'll have to figure out later if i actually want to support mac or just do linux. apparently this flag is crucial for fsync.
        };
        const fd = try posix.openat(dir_fd, relative_path, flags, 0o666);
        errdefer posix.close(fd);
        return fd;
    }

    pub fn close(io: *PosixIO, fd: fd_t) void {
        _ = io;
        posix.close(fd);
    }

    pub fn write(io: *PosixIO, fd: fd_t, bytes: []const u8) !usize {
        _ = io;
        // TODO: better error handling?
        const n = try posix.write(fd, bytes);
        // Just assume we do indeed want all disk writes fully fsync'd every time for now.
        try fs_sync(fd);
        return n;
    }

    // c.f. tigerbeetle
    fn fs_sync(fd: fd_t) !void {
        // copied from tigerbeetle. see: src/io/darwin.zig
        // TODO: This is of dubious safety - it's _not_ safe to fall back on posix.fsync unless it's
        // known at startup that the disk (eg, an external disk on a Mac) doesn't support
        // F_FULLFSYNC.
        _ = posix.fcntl(fd, posix.F.FULLFSYNC, 1) catch return posix.fsync(fd);
    }

    pub fn read(io: *PosixIO, fd: fd_t, buf: []u8, offset: u64) !usize {
        _ = io;
        return posix.pread(fd, buf, offset);
    }
};
