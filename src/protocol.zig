const std = @import("std");
const mem = std.mem;
const ascii = std.ascii;

const constants = @import("constants.zig");

pub const Operation = enum {
    get,
    set,
};

// For the time being, the wire protocol will be simple:
// <Operation> followed by whitespace-separated arguments
// "GET <key>"
// "SET <key> <value>"

pub const RequestParseError = error{
    InvalidOperation,
    MissingKey,
    MissingValue,
    KeyTooLarge,
    ValueTooLarge,
};

pub const ParsedRequest = struct {
    operation: Operation,
    key: []const u8,
    value: ?[]const u8,
};

const arg_delimiter = ' ';

pub fn parse_request(request: []const u8) RequestParseError!ParsedRequest {
    var it = mem.splitScalar(u8, request, ' ');
    const op = it.first();
    var parsed_op: Operation = undefined;
    if (mem.eql(u8, "GET", op)) {
        parsed_op = Operation.get;
    } else if (mem.eql(u8, "SET", op)) {
        parsed_op = Operation.set;
    } else {
        // Unrecognized operation
        return RequestParseError.InvalidOperation;
    }

    var parsed: ParsedRequest = .{ .operation = parsed_op, .key = undefined, .value = null };

    const request_key = it.next();
    if (request_key == null) {
        // All requests must have a key present
        return RequestParseError.MissingKey;
    }
    if (request_key.?.len > constants.MAX_KEY_SIZE) {
        return RequestParseError.KeyTooLarge;
    }
    parsed.key = mem.trimRight(u8, request_key.?, "\n");

    const maybe_value = it.next();
    if (parsed_op == Operation.set and maybe_value == null) {
        // SET requests must also have a value
        return RequestParseError.MissingValue;
    }
    if (parsed_op == Operation.set and maybe_value.?.len > constants.MAX_VALUE_SIZE) {
        return RequestParseError.ValueTooLarge;
    }
    if (parsed_op == Operation.set) {
        parsed.value = mem.trimRight(u8, maybe_value.?, "\n");
    }

    return parsed;
}

const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectEqualStrings = testing.expectEqualStrings;
const expectError = testing.expectError;

test "happy path, get request" {
    const request = "GET foo";
    const parsed = try parse_request(request);
    try expectEqual(Operation.get, parsed.operation);
    try expectEqualStrings("foo", parsed.key);
    try expect(parsed.value == null);
}

test "happy path, set request" {
    const request = "SET foo bar";
    const parsed = try parse_request(request);
    try expectEqual(Operation.set, parsed.operation);
    try expectEqualStrings("foo", parsed.key);
    try expect(parsed.value != null);
    try expectEqualStrings("bar", parsed.value.?);
}

test "unrecognized operation" {
    try expectError(RequestParseError.InvalidOperation, parse_request("FOO bar"));
}

test "get request, no key" {
    try expectError(RequestParseError.InvalidArguments, parse_request("GET"));
}

test "set request, no key" {
    try expectError(RequestParseError.InvalidArguments, parse_request("SET"));
}

test "set request, no value" {
    try expectError(RequestParseError.InvalidArguments, parse_request("SET foo"));
}
