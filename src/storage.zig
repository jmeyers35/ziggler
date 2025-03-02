const std = @import("std");
const log = std.log;
const mem = std.mem;

const assert = std.debug.assert;

pub fn StorageType(comptime IOType: type, comptime MemstoreType: type) type {
    return struct {
        const Storage = @This();

        data_dir_fd: IOType.fd_t,
        data_file_fd: IOType.fd_t,
        io: *IOType,
        memstore: MemstoreType,

        pub fn init(io: *IOType, memstore: MemstoreType, data_dir_path: []const u8) !Storage {
            const data_dir_fd = try io.open_dir(data_dir_path);
            log.info("opened data directory at {s}", .{data_dir_path});
            errdefer io.close(data_dir_fd);

            const data_file_fd = try io.open_data_file(data_dir_fd, "zigger.log");
            log.info("opened data file at {s}/ziggler.log", .{data_dir_path});
            errdefer io.close(data_file_fd);

            var storage: Storage = .{
                .data_dir_fd = data_dir_fd,
                .data_file_fd = data_file_fd,
                .io = io,
                .memstore = memstore,
            };

            try storage.load_from_disk();

            return storage;
        }

        // Try to load state from disk back into the memstore.
        fn load_from_disk(storage: *Storage) !void {
            var buf: [4096]u8 = undefined;
            var bytes_read: u64 = 0;
            while (true) {
                // TODO: error handling
                const n = try storage.io.read(storage.data_file_fd, buf[bytes_read..], bytes_read);
                if (n == 0) {
                    // EOF
                    break;
                }
                bytes_read += n;
            }

            if (bytes_read == 0) {
                return;
            }

            // Split around newlines
            // TODO: define real binary format and handle partial reads of a record, detect corruption, all that good stuff
            var records_it = mem.splitScalar(u8, buf[0..bytes_read], '\n');
            var curr_record = records_it.next();

            // We know we're not empty, so we'd better assert the data file is well-formed
            // splitScalar returns the _entire_ buffer first if the delimiter isn't found in the bytes, so if that's the case, we have a malformed data file
            assert(curr_record != null);
            assert(curr_record.?.len != bytes_read);

            while (curr_record != null) {
                const record = curr_record.?;

                if (record.len == 0) {
                    curr_record = records_it.next();
                    continue;
                }
                // For now, log entries are comma separated, with the first entry being the write operation, the second entry being the key's bytes, and the third being the value's bytes
                var record_it = mem.splitScalar(u8, record, ',');
                _ = record_it.first();

                const key = record_it.next();
                assert(key != null);

                const value = record_it.next();
                assert(value != null);

                try storage.memstore.set(key.?, value.?);

                curr_record = records_it.next();
            }
        }

        pub fn deinit(storage: *Storage) void {
            storage.io.close(storage.data_dir_fd);
            storage.io.close(storage.data_dir_fd);
            storage.memstore.deinit();
        }

        pub fn get(storage: *Storage, key: []const u8) ?[]const u8 {
            // TODO: read from disk if not in memory
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
            _ = try storage.io.write(storage.data_file_fd, buffer[0..len_needed]);
        }
    };
}
