const std = @import("std");
const fs = std.fs;
const KVStore = @import("KVStore.zig");
const tcp = @import("tcp.zig");

pub fn startServer(store: *KVStore, unix_path: []const u8, stop: bool) !void {
    // Make sure old socket is removed
    _ = fs.cwd().deleteFile(unix_path) catch {};

    const address = try std.net.Address.initUnix(unix_path);
    var listener = try address.listen(.{
        .reuse_address = true,
    });
    defer listener.deinit();
    defer fs.cwd().deleteFile(unix_path) catch {};

    while (!stop) {
        const conn = listener.accept() catch continue;

        // Read request
        var buf: [1024]u8 = undefined;
        const n = conn.stream.read(&buf) catch 0;
        if (n == 0) continue;

        const msg = buf[0..n];
        try tcp.handleConnection(conn, store, msg);
        conn.stream.close();
    }
}
