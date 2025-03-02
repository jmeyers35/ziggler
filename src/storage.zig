const std = @import("std");
const log = std.log;

const assert = std.debug.assert;

pub fn StorageType(comptime IOType: type, comptime MemstoreType: type) type {
    return struct {
        const Storage = @This();

        dataDirFD: IOType.fd_t,
        dataFileFD: IOType.fd_t,
        io: *IOType,
        memstore: MemstoreType,

        pub fn init(io: *IOType, memstore: MemstoreType, dataFileDirPath: []const u8) !Storage {
            const dataDirFD = try io.open_dir(dataFileDirPath);
            log.info("opened data directory at {s}", .{dataFileDirPath});
            errdefer io.close(dataDirFD);

            const dataFileFD = try io.open_data_file(dataDirFD, "zigger.log");
            log.info("opened data file at {s}/ziggler.log", .{dataFileDirPath});

            // TODO: read any present data back into the in-memory store

            return .{
                .dataDirFD = dataDirFD,
                .dataFileFD = dataFileFD,
                .io = io,
                .memstore = memstore,
            };
        }

        pub fn deinit(storage: *Storage) void {
            storage.io.close(storage.dataDirFD);
            storage.memstore.deinit();
        }

        pub fn get(storage: *Storage, key: []const u8) ?[]const u8 {
            return storage.memstore.get(key);
        }

        pub fn set(storage: *Storage, key: []const u8, value: []const u8) !void {
            try storage.memstore.set(key, value);
            // Write to data file
            // TODO: actually define a binary format and serialize/deserialize via abstractions
            var buffer: [2048]u8 = undefined; // TODO: actually define a maximum key length and figure out what this value should be
            const len_needed = 3 + 3 + key.len + value.len;
            assert(len_needed <= 2048);
            var buffer_stream = std.io.fixedBufferStream(&buffer);
            try std.fmt.format(buffer_stream.writer(), "SET,{s},{s}\n", .{ key, value });
            _ = try storage.io.write(storage.dataFileFD, buffer[0..len_needed]);
        }
    };
}
