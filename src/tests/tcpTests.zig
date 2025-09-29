const std = @import("std");
const tcp = @import("../tcp.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Run server in another thread
    var server_thread = try std.Thread.spawn(.{}, fn () void{
        try tcp.startServer(allocator),
    }, null);

    // Give server a moment to start
    std.time.sleep(1 * std.time.second);

    // Connect client
    const gpa = std.heap.page_allocator;
    var stream = try std.net.StreamingSocket.connectTcp(gpa, "127.0.0.1", 6379);
    defer stream.close();

    try stream.writer().writeAll("SET hello world\n");
    var buf: [1024]u8 = undefined;
    const n = try stream.reader().read(&buf);
    std.debug.print("Server response: {s}\n", .{buf[0..n]});

    try stream.writer().writeAll("GET hello\n");
    const n2 = try stream.reader().read(&buf);
    std.debug.print("Server response: {s}\n", .{buf[0..n2]});

    server_thread.wait() catch {};
}
