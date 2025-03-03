const std = @import("std");
const log = std.log;
const mem = std.mem;

const assert = std.debug.assert;

const protocol = @import("protocol.zig");
const Operation = protocol.Operation;

const constants = @import("constants.zig");

pub fn StorageType(comptime IOType: type, comptime MemstoreType: type) type {
    return struct {
        const Storage = @This();

        // TODO: i think this is going to end up being the WAL? we'll probably have a dedicated
        // struct for on-disk SSTables
        pub const LogEntry = struct {
            key: []const u8,
            value: []const u8,

            /// On-disk delimiter between `LogEntry`s
            pub const entry_delimiter = '\n';
            /// On-disk delimiter _within_ a `LogEntry` between fields. Opaque to consumers.
            const kv_delimiter = ',';

            pub fn serialize(entry: LogEntry, writer: anytype) !usize {
                const len = entry.key.len + entry.value.len + 2; // one byte each for the delimiter and
                try std.fmt.format(writer, "{s}{c}{s}{c}", .{ entry.key, kv_delimiter, entry.value, entry_delimiter });
                return len;
            }

            pub const MalformedLogError = error{
                MissingKey,
                MissingValue,
            };

            // Deserialize bytes into a LogEntry. It's assumed that the caller has done the work of
            // splitting on `entry_delimiter`, and the input is one of the results of that split.
            pub fn deserialize(bytes: []const u8) MalformedLogError!LogEntry {
                assert(bytes.len > 0);
                var fields_it = mem.splitScalar(u8, bytes, kv_delimiter);

                const key = fields_it.next();
                if (key == null) {
                    return MalformedLogError.MissingKey;
                }

                const value = fields_it.next();
                if (value == null) {
                    return MalformedLogError.MissingValue;
                }

                return .{
                    .key = key.?,
                    .value = value.?,
                };
            }
        };

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

            var entries_it = mem.splitScalar(u8, buf[0..bytes_read], LogEntry.entry_delimiter);
            var curr_entry = entries_it.next();

            // We know we're not empty, so we'd better assert the data file is well-formed
            // splitScalar returns the _entire_ buffer first if the delimiter isn't found in the bytes, so if that's the case, we have a malformed data file
            assert(curr_entry != null);
            assert(curr_entry.?.len != bytes_read);

            while (curr_entry != null) {
                const entry = curr_entry.?;

                if (entry.len == 0) {
                    curr_entry = entries_it.next();
                    continue;
                }

                const parsed_log_entry = LogEntry.deserialize(entry) catch unreachable; // Corrupt data file, bail out

                try storage.memstore.set(parsed_log_entry.key, parsed_log_entry.value);

                curr_entry = entries_it.next();
            }
        }

        pub fn deinit(storage: *Storage) void {
            storage.io.close(storage.data_dir_fd);
            storage.io.close(storage.data_dir_fd);
            storage.memstore.deinit();
        }

        pub fn get(storage: *Storage, key: []const u8) ?[]const u8 {
            return storage.memstore.get(key);
        }

        pub fn set(storage: *Storage, key: []const u8, value: []const u8) !void {
            assert(key.len > 0);
            assert(value.len > 0);
            assert(key.len <= constants.MAX_KEY_SIZE);
            assert(value.len <= constants.MAX_VALUE_SIZE);

            var buffer: [2048]u8 = undefined; // TODO: change 2048 to something more reasonable? we'd need log_entry to tell us the additional space overhead to serialize a k/v pair (delimiters)
            var buffer_stream = std.io.fixedBufferStream(&buffer);
            const log_entry: LogEntry = .{
                .key = key,
                .value = value,
            };
            const n = try log_entry.serialize(buffer_stream.writer()); // Corrupt data file; fail
            _ = try storage.io.write(storage.data_file_fd, buffer[0..n]);

            // write to log _must_ succeed before reflecting value back to clients, for durability
            try storage.memstore.set(key, value);
        }
    };
}
