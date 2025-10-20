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

    Thread.sleep(time.ns_per_ms * 200);

    var client = try zentropy.Client.connect(.{});
    client.shutdown() catch unreachable;
    client.deinit();

    server.join();
    Thread.sleep(time.ns_per_ms * 200);
}

test "set-get" {
    stop_server.store(false, .unordered);
    const server = try Thread.spawn(.{}, startServer, .{});
    defer server.join();

    Thread.sleep(time.ns_per_ms * 200);

    const ex1 = "example1";
    const ex2 = "example 2"; //with spaces
    const val1 = "value1";
    const val2 = "value 2";

    var client = try zentropy.Client.connect(.{});
    defer {
        client.shutdown() catch unreachable;
        client.deinit();
    }

    try client.set(ex1, val1);
    try client.set(ex2, val2);

    var value1_buf: [32]u8 = undefined;
    var value2_buf: [32]u8 = undefined;
    var value3_buf: [32]u8 = undefined;

    // simple .get
    const value1 = try client.get(ex1, &value1_buf) orelse unreachable;
    try testing.expectEqualSlices(u8, val1, value1);
    const value2 = try client.get(ex2, &value2_buf) orelse unreachable;
    try testing.expectEqualSlices(u8, val2, value2);
    const value3 = try client.get("not existing", &value3_buf);
    try testing.expect(value3 == null);

    // .getAlloc
    const value1_alloc = try client.getAlloc(testing.allocator, ex1) orelse unreachable;
    defer testing.allocator.free(value1_alloc);
    try testing.expectEqualSlices(u8, val1, value1_alloc);
    const value2_alloc = try client.getAlloc(testing.allocator, ex2) orelse unreachable;
    defer testing.allocator.free(value2_alloc);
    try testing.expectEqualSlices(u8, val2, value2_alloc);
    const value3_alloc = try client.getAlloc(testing.allocator, "not existing");
    try testing.expect(value3_alloc == null);

    // .getSized
    const value1_sized = try client.getSized(ex1, val1.len) orelse unreachable;
    try testing.expectEqualSlices(u8, val1, &value1_sized);
    const value2_sized = try client.getSized(ex2, val2.len) orelse unreachable;
    try testing.expectEqualSlices(u8, val2, &value2_sized);
    const value3_sized = try client.getSized("not existing", 5);
    try testing.expect(value3_sized == null);
}

test "exists" {
    stop_server.store(false, .unordered);
    const server = try Thread.spawn(.{}, startServer, .{});
    defer server.join();

    Thread.sleep(time.ns_per_ms * 200);

    var client = try zentropy.Client.connect(.{});
    defer {
        client.shutdown() catch unreachable;
        client.deinit();
    }

    try testing.expect(!try client.exists("example1"));
    try testing.expect(!try client.exists("example2"));
    try client.set("example1", "value1");
    try testing.expect(try client.exists("example1"));
    try testing.expect(!try client.exists("example2")); //double check
    try client.set("example2", "value2");
    try testing.expect(try client.exists("example2"));
}

fn startServer() !void {
    var store = KVStore.init(testing.allocator);
    defer store.deinit();
    var app_config = try config.load(testing.allocator);
    defer app_config.deinit(testing.allocator);
    try tcp.startServer(&store, &stop_server, &app_config);
}
