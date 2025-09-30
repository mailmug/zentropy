const std = @import("std");
const KVStore = @import("KVStore.zig");
const net = std.net;
const posix = std.posix;

pub fn startServer(store: *KVStore) !void {
    const address = try std.net.Address.parseIp("127.0.0.1", 9000);
    var listener = try address.listen(.{
        .reuse_address = true,
    });
    defer listener.deinit();
    std.debug.print("statr", .{});

    while (true) {
        // Wait for client
        var conn = try listener.accept();

        // Read request
        var buf: [1024]u8 = undefined;
        const n = conn.stream.read(&buf) catch 0;
        if (n == 0) continue;

        const msg = buf[0..n];
        std.debug.print("Received: {s}\n", .{msg});
        try handleConnection(conn, store, msg);
        conn.stream.close();
    }
}

fn handleConnection(conn: std.net.Server.Connection, store: *KVStore, msg: []u8) !void {
    // Parse commands: SET key value or GET key
    const allocator = std.heap.page_allocator;
    var partsList = splitToArray(msg, allocator) catch unreachable;
    defer partsList.deinit(allocator);
    const parts = partsList.items;
    if (parts.len == 0) {
        return;
    }
    const cmd = parts[0];
    if (std.mem.eql(u8, cmd, "SET")) {
        if (parts.len != 3) {
            _ = try conn.stream.writeAll("-ERR wrong number of arguments\r\n");
            return;
        }
        try store.put(parts[1], parts[2]);
        _ = try conn.stream.writeAll("+OK\r\n");
    } else if (std.mem.eql(u8, cmd, "GET")) {
        if (parts.len != 2) {
            _ = try conn.stream.writeAll("-ERR wrong number of arguments\r\n");
            return;
        }
        const val = store.get(parts[1]);
        std.debug.print("0000 {s}", .{parts[1]});

        if (val) |v| {
            _ = try conn.stream.writeAll(v);
            _ = try conn.stream.writeAll("\r\n");
        } else {
            _ = try conn.stream.writeAll("$-1\r\n");
        }
    } else {
        _ = try conn.stream.writeAll("-ERR unknown command\r\n");
    }
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
