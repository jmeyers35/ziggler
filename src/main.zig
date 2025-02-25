const std = @import("std");
const server = @import("server.zig");

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);

    // get a server
    const addr = try std.net.Address.resolveIp("127.0.0.1", 8080);
    const opts = server.ServerOpts{
        .addr = addr,
        .message = "hello, jacob",
    };

    var srv = try server.Server.init(opts);
    try srv.listen();

    try bw.flush(); // don't forget to flush!
}
