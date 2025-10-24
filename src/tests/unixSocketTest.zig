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

    const response = readResponse(conn, &buf) catch unreachable;
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
    const response = readResponse(conn, &buf) catch unreachable;
    try std.testing.expect(std.mem.indexOf(u8, response, "+SHUTDOWN initiated") != null);
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
    defer store.deinit();

    unixSocket.startServer(&store, socket_path, &stop_server) catch |err| {
        std.debug.print("Server error: {}\n", .{err});
    };
}

pub fn readResponse(conn: std.net.Stream, buf: []u8) ![]u8 {
    const bytes_read = try conn.read(buf);
    return buf[0..bytes_read];
}

// Simple check for Redis protocol completeness
fn isCompleteRedisResponse(data: []const u8) bool {
    if (data.len == 0) return false;
    // Very basic check - in reality, parse Redis protocol properly
    return data[data.len - 1] == '\n';
}
