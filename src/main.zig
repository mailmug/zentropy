const std = @import("std");
const KVStore = @import("KVStore.zig");
const tcp = @import("tcp.zig");
const unixSocket = @import("unixSocket.zig");
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    // const allocator = gpa.allocator();
    // defer _ = gpa.deinit();
    var store = KVStore.init(allocator);
    defer store.deinit();

    // const socket_path = "/tmp/zentropy.sock";

    var stop_server: std.atomic.Value(bool) = std.atomic.Value(bool).init(false);

    // Start TCP server in a thread
    var tcp_thread = try std.Thread.spawn(.{}, tcp.startServer, .{ &store, &stop_server });

    // Start Unix socket server in main thread (or another thread)
    // var unix_thread = try std.Thread.spawn(.{}, unixSocket.startServer, .{ &store, socket_path, allocator, &stop_server });

    // Wait for both servers (they will likely run forever)
    tcp_thread.join();
    // unix_thread.join();
}

fn startUnixSocketServer() void {}
