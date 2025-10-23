const std = @import("std");
const KVStore = @import("KVStore.zig");
const commands = @This();
const info = @import("info.zig");
const posix = std.posix;

const Command = enum {
    ping,
    info,
    set,
    get,
    exists,
    delete,
    shutdown,
    unknown,

    pub fn fromString(cmd_str: []const u8) Command {
        const trimmed_cmd = std.mem.trim(u8, cmd_str, "\r\n");

        if (std.mem.eql(u8, trimmed_cmd, "PING")) return .ping;
        if (std.mem.eql(u8, trimmed_cmd, "INFO")) return .info;
        if (std.mem.eql(u8, trimmed_cmd, "SET")) return .set;
        if (std.mem.eql(u8, trimmed_cmd, "GET")) return .get;
        if (std.mem.eql(u8, trimmed_cmd, "EXISTS")) return .exists;
        if (std.mem.eql(u8, trimmed_cmd, "DELETE")) return .delete;
        if (std.mem.eql(u8, trimmed_cmd, "SHUTDOWN")) return .shutdown;

        return .unknown;
    }
};

const ParseResult = struct {
    command: Command,
    args: []const []const u8,
};

pub fn parseCmd(fd: posix.fd_t, store: *KVStore, msg: []const u8) ?[]const u8 {
    // Stack-allocated buffer for command parts
    var parts_buffer: [10][]const u8 = undefined;
    const parts = parseCommand(msg, &parts_buffer);

    if (parts.len == 0) {
        return null;
    }

    const parse_result = ParseResult{
        .command = Command.fromString(parts[0]),
        .args = parts[1..],
    };

    return switch (parse_result.command) {
        .ping => handlePing(fd, parse_result.args),
        .info => handleInfo(fd, store, parse_result.args),
        .set => handleSet(fd, store, parse_result.args),
        .get => handleGet(fd, store, parse_result.args),
        .exists => handleExists(fd, store, parse_result.args),
        .delete => handleDelete(fd, store, parse_result.args),
        .shutdown => handleShutdown(fd, parse_result.args),
        .unknown => handleUnknown(fd, parse_result.args),
    };
}

fn handlePing(fd: posix.fd_t, args: []const []const u8) ?[]const u8 {
    if (!validateArgumentCount(args.len, 0, fd)) return null;
    _ = sendResponse(fd, "+PONG\r\n");
    return null;
}

fn handleInfo(fd: posix.fd_t, store: *KVStore, args: []const []const u8) ?[]const u8 {
    if (!validateArgumentCount(args.len, 0, fd)) return null;

    const info_str = info.name ++ " " ++ info.version;
    _ = sendResponse(fd, info_str ++ "\r\n");
    _ = store;
    return null;
}

fn handleSet(fd: posix.fd_t, store: *KVStore, args: []const []const u8) ?[]const u8 {
    if (args.len < 2) {
        _ = sendError(fd, "ERR wrong number of arguments for SET");
        return null;
    }

    const key = std.mem.trim(u8, args[0], "\r\n");
    const value = std.mem.trim(u8, args[1], "\r\n");

    if (args.len == 2) {
        // SET key value
        store.set(key, value) catch {};
        _ = sendResponse(fd, "+OK\r\n");
    } else if (args.len == 4) {
        // SET key value EX seconds | PX milliseconds
        const expire_type = std.mem.trim(u8, args[2], "\r\n");
        const expire_str = std.mem.trim(u8, args[3], "\r\n");

        if (parseExpireTime(expire_type, expire_str, fd)) |ms| {
            store.setWithExpiry(key, value, ms) catch {};
            _ = sendResponse(fd, "+OK\r\n");
        }
    } else {
        _ = sendError(fd, "ERR syntax error");
    }

    return null;
}

fn handleGet(fd: posix.fd_t, store: *KVStore, args: []const []const u8) ?[]const u8 {
    if (!validateArgumentCount(args.len, 1, fd)) return null;

    const key = std.mem.trim(u8, args[0], "\r\n");

    if (store.get(key)) |value| {
        _ = sendBulkResponse(fd, value);
    } else {
        _ = sendResponse(fd, "$-1\r\n");
    }

    return null;
}

fn handleExists(fd: posix.fd_t, store: *KVStore, args: []const []const u8) ?[]const u8 {
    if (!validateArgumentCount(args.len, 1, fd)) return null;

    const key = std.mem.trim(u8, args[0], "\r\n");
    const exists = store.contains(key);

    _ = sendIntegerResponse(fd, if (exists) 1 else 0);
    return null;
}

fn handleDelete(fd: posix.fd_t, store: *KVStore, args: []const []const u8) ?[]const u8 {
    if (!validateArgumentCount(args.len, 1, fd)) return null;

    const key = std.mem.trim(u8, args[0], "\r\n");

    if (store.delete(key)) {
        _ = sendIntegerResponse(fd, 1);
    } else {
        _ = sendIntegerResponse(fd, 0);
    }

    return null;
}

fn handleShutdown(fd: posix.fd_t, args: []const []const u8) ?[]const u8 {
    if (!validateArgumentCount(args.len, 0, fd)) return null;
    _ = sendResponse(fd, "+SHUTDOWN initiated\r\n");
    return "SHUTDOWN";
}

fn handleUnknown(fd: posix.fd_t, args: []const []const u8) ?[]const u8 {
    _ = args; // unused
    _ = sendError(fd, "ERR unknown command");
    return null;
}

fn parseExpireTime(expire_type: []const u8, expire_str: []const u8, fd: posix.fd_t) ?u32 {
    if (std.mem.eql(u8, expire_type, "EX")) {
        if (std.fmt.parseInt(u32, expire_str, 10)) |seconds| {
            return seconds * 1000;
        } else |_| {
            _ = sendError(fd, "ERR invalid expire time");
            return null;
        }
    } else if (std.mem.eql(u8, expire_type, "PX")) {
        if (std.fmt.parseInt(u32, expire_str, 10)) |ms| {
            return ms;
        } else |_| {
            _ = sendError(fd, "ERR invalid expire time");
            return null;
        }
    } else {
        _ = sendError(fd, "ERR syntax error");
        return null;
    }
}

fn parseCommand(msg: []const u8, output: []([]const u8)) []const []const u8 {
    var count: usize = 0;
    var i: usize = 0;
    const len = msg.len;

    while (i < len and count < output.len) {
        // Skip leading whitespace
        while (i < len and std.ascii.isWhitespace(msg[i])) i += 1;
        if (i >= len) break;

        const start = i;

        if (msg[i] == '"' or msg[i] == '\'') {
            // Quoted string handling
            const quote_char = msg[i];
            i += 1; // Skip opening quote
            const quote_start = i;

            // Find closing quote
            while (i < len and msg[i] != quote_char) i += 1;

            if (i < len) {
                output[count] = msg[quote_start..i];
                count += 1;
                i += 1; // Skip closing quote
            } else {
                // No closing quote, take until end
                output[count] = msg[quote_start..];
                count += 1;
                break;
            }
        } else {
            // Regular word
            while (i < len and !std.ascii.isWhitespace(msg[i])) i += 1;
            output[count] = msg[start..i];
            count += 1;
        }
    }

    return output[0..count];
}

fn validateArgumentCount(actual: usize, expected: usize, fd: posix.fd_t) bool {
    if (actual != expected) {
        _ = sendError(fd, "ERR wrong number of arguments");
        return false;
    }
    return true;
}

fn sendResponse(fd: posix.fd_t, response: []const u8) bool {
    const bytes_written = posix.write(fd, response) catch return false;
    return bytes_written == response.len;
}

fn sendError(fd: posix.fd_t, error_msg: []const u8) bool {
    // Use a fixed buffer and format the response
    var buffer: [256]u8 = undefined;

    if (std.fmt.bufPrint(&buffer, "-{s}\r\n", .{error_msg})) |response| {
        return sendResponse(fd, response);
    } else |_| {
        return sendResponse(fd, "-ERR\r\n");
    }
}

fn sendBulkResponse(fd: posix.fd_t, value: []const u8) bool {
    var buffer: [128]u8 = undefined;
    if (std.fmt.bufPrint(&buffer, "${}\r\n", .{value.len})) |len_str| {
        if (!sendResponse(fd, len_str)) return false;
        if (!sendResponse(fd, value)) return false;
        return sendResponse(fd, "\r\n");
    } else |_| {
        _ = sendError(fd, "ERR response too large");
        return false;
    }
}

fn sendIntegerResponse(fd: posix.fd_t, value: i64) bool {
    var buffer: [32]u8 = undefined;
    if (std.fmt.bufPrint(&buffer, ":{}\r\n", .{value})) |response| {
        return sendResponse(fd, response);
    } else |_| {
        _ = sendError(fd, "ERR integer formatting error");
        return false;
    }
}
