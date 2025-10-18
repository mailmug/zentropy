const std = @import("std");
const zentropy = @import("zentropy");
const testing = std.testing;
const KVStore = @import("../KVStore.zig");
const config = @import("../config.zig");
const tcp = @import("../tcp.zig");
const time = std.time;
const Thread = std.Thread;

var stop_server = std.atomic.Value(bool).init(false);

test "connect" {
    stop_server.store(false, .unordered);
    const server = try Thread.spawn(.{}, startServer, .{});

    Thread.sleep(time.ns_per_ms * 1000);

    var client = try zentropy.Client.connect(.{});
    client.shutdown() catch unreachable;
    client.deinit();

    server.join();
    Thread.sleep(time.ns_per_ms * 1000);
}

test "set-get" {
    stop_server.store(false, .unordered);
    const server = try Thread.spawn(.{}, startServer, .{});

    Thread.sleep(time.ns_per_ms * 1000);

    var client = try zentropy.Client.connect(.{});

    try client.set("example1", "value1");
    try client.set("example2", "value2");

    var value1_buf: [32]u8 = undefined;
    var value2_buf: [32]u8 = undefined;

    const value1 = try client.get("example1", &value1_buf) orelse unreachable;
    try testing.expectEqualSlices(u8, "value1", value1);
    const value2 = try client.get("example2", &value2_buf) orelse unreachable;
    try testing.expectEqualSlices(u8, "value2", value2);
    client.shutdown() catch unreachable;
    client.deinit();

    server.join();
}

fn startServer() !void {
    var store = KVStore.init(testing.allocator);
    defer store.deinit();
    var app_config = try config.load(testing.allocator);
    defer app_config.deinit(testing.allocator);
    try tcp.startServer(&store, &stop_server, &app_config);
}
