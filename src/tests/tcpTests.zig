const std = @import("std");
const tcp = @import("../tcp.zig");
const KVStore = @import("../KVStore.zig");

test "tcp server responds" {
    const allocator = std.heap.page_allocator;

    // Run server in another thread
    var server_thread = try std.Thread.spawn(.{}, start, .{allocator});
    defer server_thread.join();

    // Give server a moment to start
    std.Thread.sleep(1 * std.time.ns_per_s);

    // Client connects
    const address = try std.net.Address.parseIp4("127.0.0.1", 9000);
    var conn = try std.net.tcpConnectToAddress(address);
    defer conn.close();
    var buf: [1024]u8 = undefined;
    var writer = conn.writer(&buf);
    const w = &writer.interface;
    w.writeAll("ping") catch unreachable;
    w.flush() catch unreachable;

    var reader = conn.reader(&.{});
    const r = reader.interface();
    _ = r.readSliceShort(&buf) catch 0;
    const response = buf[0..];
    try std.testing.expect(std.mem.indexOf(u8, response, "Hello from Zig!") != null);
}

fn start(allocator: std.mem.Allocator) void {
    const store = KVStore.init(allocator);

    tcp.startServer(&store) catch |err| {
        std.debug.print("Server error: {}\n", .{err});
    };
}
