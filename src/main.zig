const std = @import("std");
const log = std.log;
const assert = std.debug.assert;

const server = @import("server.zig");
const io = @import("io.zig");
const kv = @import("kv.zig");
const storage = @import("storage.zig");

const clap = @import("clap");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == std.heap.Check.ok);
    const alloc = gpa.allocator();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help  Display this help and exit.
        \\-p, --port <u16>  The port to listen on (default: 42069)
    );

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = alloc,
    }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    }

    const port: u16 = if (res.args.port) |p| p else 42069;

    const addr = try std.net.Address.resolveIp("127.0.0.1", port);
    var posix_io = try io.PosixIO.init();
    defer posix_io.deinit();

    const mem_storage = kv.InMemoryStore.init(alloc);

    var disk_storage = try storage.StorageType(io.PosixIO, kv.InMemoryStore).init(&posix_io, mem_storage, "/tmp/ziggler/test");
    defer disk_storage.deinit();

    var srv = try server.ServerType(io.PosixIO, storage.StorageType(io.PosixIO, kv.InMemoryStore)).init(posix_io, disk_storage, addr);
    log.info("starting ziggler server on port {d}", .{port});
    try srv.listen();
}
