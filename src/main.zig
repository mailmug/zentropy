const std = @import("std");
const KVStore = @import("KVStore.zig");
const tcp = @import("tcp.zig");
const unixSocket = @import("unixSocket.zig");
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var store = KVStore.init(allocator);
    defer store.deinit();

    const socket_path = "/tmp/zentropy.sock";
    var stop_server: bool = false;

    // Start TCP server in a thread
    var tcp_thread = try std.Thread.spawn(.{}, tcp.startServer, .{ &store, allocator, &stop_server });

    // Start Unix socket server in main thread (or another thread)
    var unix_thread = try std.Thread.spawn(.{}, unixSocket.startServer, .{ &store, socket_path, allocator, &stop_server });

    // Wait for both servers (they will likely run forever)
    tcp_thread.join();
    unix_thread.join();
}

fn startUnixSocketServer() void {}
