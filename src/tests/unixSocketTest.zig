const std = @import("std");
const KVStore = @import("../KVStore.zig");
const unixSocket = @import("../unixSocket.zig");
var stop_server: std.atomic.Value(bool) = std.atomic.Value(bool).init(false);
var server_thread: ?std.Thread = null;
const socket_path = "/tmp/zentropy.sock";

test "unix socket server responds" {
    server_thread = try std.Thread.spawn(.{}, startServer, .{});
    std.Thread.sleep(1 * std.time.ns_per_s);
    // Client connects
    var conn = try std.net.connectUnixSocket(socket_path);
    defer conn.close();
    var buf: [1024]u8 = undefined;
    var writer = conn.writer(&buf);
    const w = &writer.interface;
    w.writeAll("PING") catch unreachable;
    w.flush() catch unreachable;

    const response = readResponse(conn, &buf);
    try std.testing.expect(std.mem.indexOf(u8, response, "PONG") != null);
}

test "stop server" {
    // SHUTDOWN
    var conn = try std.net.connectUnixSocket(socket_path);
    defer conn.close();
    var buf: [1024]u8 = undefined;
    var writer = conn.writer(&buf);
    const w = &writer.interface;
    w.writeAll("SHUTDOWN") catch unreachable;
    w.flush() catch unreachable;
    const response = readResponse(conn, &buf);
    try std.testing.expect(std.mem.indexOf(u8, response, "===SHUTDOWN===") != null);
    defer server_thread.?.join();
}

fn startServer() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const check = gpa.deinit();
        switch (check) {
            .ok => {},
            .leak => @panic("Memory leak detected!"),
        }
    }

    const allocator = gpa.allocator();
    var store = KVStore.init(allocator);

    unixSocket.startServer(&store, socket_path, allocator, &stop_server) catch |err| {
        std.debug.print("Server error: {}\n", .{err});
    };
}

pub fn readResponse(conn: std.net.Stream, buf: []u8) []u8 {
    var reader = conn.reader(&.{});
    const r = reader.interface();

    var pos: usize = 0;
    while (pos < buf.len) {
        const n = r.readSliceShort(buf[pos..]) catch 0;
        if (n == 0) break;
        pos += n;
    }

    return buf[0..pos];
}
