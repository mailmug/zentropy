const std = @import("std");
const KVStore = @import("kvstore.zig").KVStore;

pub fn startServer(allocator: *std.mem.Allocator) !void {
    var store = try KVStore.init(allocator);

    var listener = try std.net.StreamServer.listenTcp(allocator, "127.0.0.1", 6379, 10);
    defer listener.close();
    std.debug.print("Zentropy TCP server running on 127.0.0.1:6379\n", .{});

    while (true) {
        const conn = try listener.accept();
        std.debug.print("New connection!\n", .{});
        handleConnection(conn, &store) catch {};
    }
}

fn handleConnection(conn: std.net.StreamServer.TcpStream, store: *KVStore) !void {
    defer conn.close();
    var buffer: [1024]u8 = undefined;

    while (true) {
        const n = try conn.read(&buffer);
        if (n == 0) break;
        const input = buffer[0..n];

        // Parse simple commands: SET key value or GET key
        const parts = std.mem.split(input, " ");
        if (parts.len == 0) continue;

        const cmd = parts[0];
        if (std.mem.eql(u8, cmd, "SET")) {
            if (parts.len != 3) {
                _ = try conn.writeAll("-ERR wrong number of arguments\r\n");
                continue;
            }
            try store.set(parts[1], parts[2]);
            _ = try conn.writeAll("+OK\r\n");
        } else if (std.mem.eql(u8, cmd, "GET")) {
            if (parts.len != 2) {
                _ = try conn.writeAll("-ERR wrong number of arguments\r\n");
                continue;
            }
            const val = store.get(parts[1]);
            if (val) |v| {
                _ = try conn.writeAll(v ++ "\r\n");
            } else {
                _ = try conn.writeAll("$-1\r\n");
            }
        } else {
            _ = try conn.writeAll("-ERR unknown command\r\n");
        }
    }
}
