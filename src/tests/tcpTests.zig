const std = @import("std");
const tcp = @import("../tcp.zig");
const KVStore = @import("../KVStore.zig");
var stop_server: std.atomic.Value(bool) = std.atomic.Value(bool).init(false);
var server_thread: ?std.Thread = null;

test "tcp server responds" {
    const allocator = std.testing.allocator;

    // Run server in another thread
    server_thread = try std.Thread.spawn(.{}, startServer, .{allocator});

    // Give server a moment to start
    std.Thread.sleep(1 * std.time.ns_per_s);

    // Client connects
    const address = try std.net.Address.parseIp4("127.0.0.1", 6383);
    var conn = try std.net.tcpConnectToAddress(address);
    defer conn.close();
    var buf: [1024]u8 = undefined;
    var writer = conn.writer(&buf);
    const w = &writer.interface;
    w.writeAll("PING") catch unreachable;
    w.flush() catch unreachable;

    const response = readResponse(conn, &buf);
    try std.testing.expect(std.mem.indexOf(u8, response, "PONG") != null);
}

test "tcp server set data" {
    // Client connects
    const address = try std.net.Address.parseIp4("127.0.0.1", 6383);
    var conn = try std.net.tcpConnectToAddress(address);
    defer conn.close();
    var buf: [1024]u8 = undefined;
    var writer = conn.writer(&buf);
    const w = &writer.interface;
    w.writeAll("SET apple red") catch unreachable;
    w.flush() catch unreachable;

    const response = readResponse(conn, &buf);
    try std.testing.expect(std.mem.indexOf(u8, response, "+OK") != null);
}

test "tcp server set data second" {

    // Client connects
    const address = try std.net.Address.parseIp4("127.0.0.1", 6383);
    var conn = try std.net.tcpConnectToAddress(address);
    defer conn.close();
    var buf: [1024]u8 = undefined;
    var writer = conn.writer(&buf);
    const w = &writer.interface;
    w.writeAll("SET sky blue") catch unreachable;
    w.flush() catch unreachable;

    const response = readResponse(conn, &buf);
    try std.testing.expect(std.mem.indexOf(u8, response, "+OK") != null);
}

test "tcp server set data third" {

    // Client connects
    const address = try std.net.Address.parseIp4("127.0.0.1", 6383);
    var conn = try std.net.tcpConnectToAddress(address);
    defer conn.close();
    var buf: [1024]u8 = undefined;
    var writer = conn.writer(&buf);
    const w = &writer.interface;
    w.writeAll("SET fruit jackfruit") catch unreachable;
    w.flush() catch unreachable;

    const response = readResponse(conn, &buf);
    try std.testing.expect(std.mem.indexOf(u8, response, "+OK") != null);
}

test "tcp server get data" {

    // Client connects
    const address = try std.net.Address.parseIp4("127.0.0.1", 6383);
    var conn = try std.net.tcpConnectToAddress(address);
    defer conn.close();
    var buf: [1024]u8 = undefined;
    var writer = conn.writer(&buf);
    const w = &writer.interface;
    w.writeAll("GET apple") catch unreachable;
    w.flush() catch unreachable;

    const response = readResponse(conn, &buf);
    try std.testing.expect(std.mem.indexOf(u8, response, "red") != null);
}

test "stop server" {
    // SHUTDOWN
    const address = try std.net.Address.parseIp4("127.0.0.1", 6383);
    var conn = try std.net.tcpConnectToAddress(address);
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

fn startServer(allocator: std.mem.Allocator) void {
    var store = KVStore.init(allocator);
    defer store.deinit();

    tcp.startServer(&store, allocator, &stop_server) catch |err| {
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
