const std = @import("std");
const fs = std.fs;
const KVStore = @import("KVStore.zig");
const tcp = @import("tcp.zig");
const shutdown = @import("shutdown.zig");

pub fn startServer(store: *KVStore, unix_path: []const u8, allocator: std.mem.Allocator, stop_server: *std.atomic.Value(bool)) !void {
    // Make sure old socket is removed
    _ = fs.cwd().deleteFile(unix_path) catch {};

    const address = try std.net.Address.initUnix(unix_path);
    var listener = try address.listen(.{
        .reuse_address = true,
    });
    defer listener.deinit();
    defer fs.cwd().deleteFile(unix_path) catch {};
    while (!stop_server.load(.seq_cst)) {
        const conn = listener.accept() catch continue;

        // Read request
        var buf: [1024]u8 = undefined;
        const n = conn.stream.read(&buf) catch 0;
        if (n == 0) continue;

        const msg = buf[0..n];
        const result = try tcp.handleConnection(conn, store, msg, allocator);

        if (std.mem.eql(u8, result, "SHUTDOWN")) {
            stop_server.store(true, .seq_cst);
            shutdown.send("tcp") catch {};
        }
        conn.stream.close();
    }
}
