pub fn StorageType(comptime _: type) type {
    return struct {
        const Storage = @This();
    };
}
