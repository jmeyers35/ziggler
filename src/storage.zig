const std = @import("std");
const log = std.log;

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
            return storage.memstore.set(key, value);
        }
    };
}
