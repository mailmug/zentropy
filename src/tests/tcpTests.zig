const std = @import("std");
const tcp = @import("../tcp.zig");
const KVStore = @import("../KVStore.zig");
var stop_server: std.atomic.Value(bool) = std.atomic.Value(bool).init(false);
var server_thread: ?std.Thread = null;
const config = @import("../config.zig");

test "tcp server responds" {

    // Run server in another thread
    server_thread = try std.Thread.spawn(.{}, startServer, .{});

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

    const response = readResponse(conn, &buf) catch unreachable;
    try std.testing.expect(std.mem.indexOf(u8, response, "+PONG") != null);
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

    const response = readResponse(conn, &buf) catch unreachable;
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

    const response = readResponse(conn, &buf) catch unreachable;
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

    const response = readResponse(conn, &buf) catch unreachable;
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

    const response = readResponse(conn, &buf) catch unreachable;
    try std.testing.expect(std.mem.indexOf(u8, response, "red") != null);
}

test "tcp server exists data" {

    // Client connects
    const address = try std.net.Address.parseIp4("127.0.0.1", 6383);
    var conn = try std.net.tcpConnectToAddress(address);
    defer conn.close();
    var buf: [1024]u8 = undefined;
    var writer = conn.writer(&buf);
    const w = &writer.interface;
    w.writeAll("EXISTS apple") catch unreachable;
    w.flush() catch unreachable;

    const response = readResponse(conn, &buf) catch unreachable;
    try std.testing.expect(std.mem.indexOf(u8, response, "1") != null);
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
    const response = readResponse(conn, &buf) catch unreachable;
    try std.testing.expect(std.mem.indexOf(u8, response, "+SHUTDOWN initiated") != null);
    defer server_thread.?.join();
}

fn startServer() !void {
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
    var app_config = try config.load(allocator, null);
    defer app_config.deinit(allocator);
    tcp.startServer(&store, &stop_server, &app_config) catch |err| {
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
