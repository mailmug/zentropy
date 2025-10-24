const std = @import("std");
const builtin = @import("builtin");
const KVStore = @import("KVStore.zig");
const tcp = @import("tcp.zig");
const unixSocket = @import("unixSocket.zig");
const config = @import("config.zig");
const cli = @import("cli.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = if (builtin.mode == .Debug)
        gpa.allocator()
    else
        std.heap.page_allocator;

    defer if (builtin.mode == .Debug) {
        switch (gpa.deinit()) {
            .ok => {},
            .leak => @panic("Memory leak detected!"),
        }
    };

    const options = cli.parse();

    var store = KVStore.init(allocator);
    defer store.deinit();

    const socket_path = "/tmp/zentropy.sock";

    var stop_server: std.atomic.Value(bool) = std.atomic.Value(bool).init(false);

    var app_config = try config.load(allocator, options.config);
    defer app_config.deinit(allocator);

    if (options.start) {

        // Start TCP server in a thread
        var tcp_thread = try std.Thread.spawn(.{}, tcp.startServer, .{ &store, &stop_server, &app_config });

        // Start Unix socket server in main thread (or another thread)
        var unix_thread = try std.Thread.spawn(.{}, unixSocket.startServer, .{ &store, socket_path, &stop_server });

        // Wait for both servers (they will likely run forever)
        tcp_thread.join();
        unix_thread.join();
    }
}

fn startUnixSocketServer() void {}
