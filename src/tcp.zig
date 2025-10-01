const std = @import("std");
const KVStore = @import("KVStore.zig");
const net = std.net;
const posix = std.posix;
const tcp = @This();
const shutdown = @import("shutdown.zig");
const commands = @import("commands.zig");

pub fn startServer(store: *KVStore, allocator: std.mem.Allocator, stop_server: *std.atomic.Value(bool)) !void {
    const address = try std.net.Address.parseIp("127.0.0.1", 6383);
    var listener = try address.listen(.{
        .reuse_address = true,
    });
    defer listener.deinit();

    while (!stop_server.load(.seq_cst)) {
        var conn = listener.accept() catch continue;

        // Read request
        var buf: [1024]u8 = undefined;
        const n = conn.stream.read(&buf) catch 0;
        if (n == 0) continue;

        const msg = buf[0..n];
        const result = try handleConnection(conn, store, msg, allocator);

        if (std.mem.eql(u8, result, "SHUTDOWN")) {
            stop_server.store(true, .seq_cst);
            shutdown.send("unix_socket") catch {};
        }
        conn.stream.close();
    }
}

pub fn handleConnection(conn: std.net.Server.Connection, store: *KVStore, msg: []u8, allocator: std.mem.Allocator) ![]const u8 {
    return commands.parseCmd(conn, store, msg, allocator);
}
