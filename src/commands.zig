const std = @import("std");
const KVStore = @import("KVStore.zig");
const commands = @This();

pub fn parseCmd(conn: std.net.Server.Connection, store: *KVStore, msg: []u8, allocator: std.mem.Allocator) ![]const u8 {
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
        if (validCheckCmdLen(parts.len, 1, conn)) {
            _ = try conn.stream.writeAll("PONG\r\n");
            return "";
        }
    } else if (std.mem.eql(u8, cmd, "SET")) {
        if (validCheckCmdLen(parts.len, 3, conn)) {
            try store.put(parts[1], parts[2]);
            _ = try conn.stream.writeAll("+OK\r\n");
            return "";
        }
    } else if (std.mem.eql(u8, cmd, "GET")) {
        if (validCheckCmdLen(parts.len, 2, conn)) {
            const key = parts[1];
            const key_str = std.mem.trim(u8, key, "\r\n");
            const val = store.get(key_str);

            if (val) |v| {
                _ = try conn.stream.writeAll(v);
                _ = try conn.stream.writeAll("\r\n");
            } else {
                _ = try conn.stream.writeAll("NONE\r\n");
            }
            return "";
        }
    } else if (std.mem.eql(u8, cmd, "EXISTS")) {
        if (validCheckCmdLen(parts.len, 2, conn)) {
            const key = parts[1];
            const key_str = std.mem.trim(u8, key, "\r\n");
            const exists = store.contains(key_str);

            if (exists) {
                _ = try conn.stream.writeAll("1\r\n");
            } else {
                _ = try conn.stream.writeAll("0\r\n");
            }
            return "";
        }
    } else if (std.mem.eql(u8, cmd, "DELETE")) {
        if (validCheckCmdLen(parts.len, 2, conn)) {
            const key = parts[1];
            if (store.delete(key)) {
                try conn.stream.writeAll("+DELETED\r\n");
                return "";
            }
            try conn.stream.writeAll("NOT DELETED\r\n");
            return "";
        }
    } else if (std.mem.eql(u8, cmd, "SHUTDOWN")) {
        try conn.stream.writeAll("===SHUTDOWN===\r\n");
        return "SHUTDOWN";
    } else {
        if (validCheckCmdLen(parts.len, 2, conn)) {
            _ = try conn.stream.writeAll("-ERR unknown command\r\n");
            return "";
        }
    }
    return "";
}

fn validCheckCmdLen(len: usize, expectedLen: usize, conn: std.net.Server.Connection) bool {
    if (len != expectedLen) {
        _ = conn.stream.writeAll("-ERR wrong number of arguments\r\n") catch {};
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
