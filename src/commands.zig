const std = @import("std");
const KVStore = @import("KVStore.zig");
const commands = @This();
const info = @import("info.zig");
const posix = std.posix;

pub fn parseCmd(fd: posix.fd_t, store: *KVStore, msg: []u8, allocator: std.mem.Allocator) ![]const u8 {
    var partsList = splitToArray(msg, allocator) catch unreachable;
    defer {
        for (partsList.items) |part| {
            allocator.free(part);
        }
        partsList.deinit(allocator);
    }

    const parts = partsList.items;
    if (parts.len == 0) {
        return "";
    }

    const _cmd = parts[0];
    const cmd = std.mem.trim(u8, _cmd, "\r\n");

    if (std.mem.eql(u8, cmd, "PING")) {
        if (validCheckCmdLen(parts.len, 1, fd)) {
            _ = try posix.write(fd, "PONG\r\n");
            return "";
        }
    } else if (std.mem.eql(u8, cmd, "INFO")) {
        if (validCheckCmdLen(parts.len, 1, fd)) {
            const infoStr = info.name ++ " " ++ info.version;
            _ = try posix.write(fd, infoStr ++ "\r\n");
            const count = store.count();
            const message = try std.fmt.allocPrint(allocator, "total_keys:{}\r\n", .{count});
            defer allocator.free(message);
            _ = try posix.write(fd, message);
            return "";
        }
    } else if (std.mem.eql(u8, cmd, "SET")) {
        if (validCheckCmdLen(parts.len, 3, fd)) {
            try store.put(parts[1], parts[2]);
            _ = try posix.write(fd, "+OK\r\n");
            return "";
        }
    } else if (std.mem.eql(u8, cmd, "GET")) {
        if (validCheckCmdLen(parts.len, 2, fd)) {
            const key = parts[1];
            const key_str = std.mem.trim(u8, key, "\r\n");
            const val = store.get(key_str);

            if (val) |v| {
                _ = try posix.write(fd, v);
                _ = try posix.write(fd, "\r\n");
            } else {
                _ = try posix.write(fd, "NONE\r\n");
            }
            return "";
        }
    } else if (std.mem.eql(u8, cmd, "EXISTS")) {
        if (validCheckCmdLen(parts.len, 2, fd)) {
            const key = parts[1];
            const key_str = std.mem.trim(u8, key, "\r\n");
            const exists = store.contains(key_str);

            if (exists) {
                _ = try posix.write(fd, "1\r\n");
            } else {
                _ = try posix.write(fd, "0\r\n");
            }
            return "";
        }
    } else if (std.mem.eql(u8, cmd, "DELETE")) {
        if (validCheckCmdLen(parts.len, 2, fd)) {
            const key = parts[1];
            if (store.delete(key)) {
                _ = posix.write(fd, "+DELETED\r\n") catch {};
                return "";
            }
            _ = posix.write(fd, "NOT DELETED\r\n") catch {};
            return "";
        }
    } else if (std.mem.eql(u8, cmd, "SHUTDOWN")) {
        _ = posix.write(fd, "===SHUTDOWN===\r\n") catch {};
        return "SHUTDOWN";
    } else {
        if (validCheckCmdLen(parts.len, 2, fd)) {
            _ = posix.write(fd, "-ERR unknown command\r\n") catch {};
            return "";
        }
    }
    return "";
}

fn validCheckCmdLen(len: usize, expectedLen: usize, fd: i32) bool {
    if (len != expectedLen) {
        _ = posix.write(fd, "-ERR wrong number of arguments\r\n") catch {};
        return false;
    }
    return true;
}

fn splitToArray(msg: []u8, allocator: std.mem.Allocator) !std.ArrayList([]u8) {
    var parts_list = try std.ArrayList([]u8).initCapacity(allocator, 3);
    var iter = std.mem.splitSequence(u8, msg, " ");

    while (iter.next()) |p| {
        const mutable_part = try allocator.dupe(u8, p);
        try parts_list.append(allocator, mutable_part);
    }

    return parts_list;
}
