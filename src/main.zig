const std = @import("std");
const log = std.log;
const assert = std.debug.assert;

const server = @import("server.zig");
const io = @import("io.zig");
const kv = @import("kv.zig");

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
    var netIO = try io.IO.init();
    defer netIO.deinit();

    var memStorage = kv.InMemoryStore.init(alloc);
    defer memStorage.deinit();

    var srv = try server.ServerType(io.IO, kv.InMemoryStore).init(netIO, memStorage, addr);
    log.info("starting ziggler server on port {d}", .{port});
    try srv.listen();
}
