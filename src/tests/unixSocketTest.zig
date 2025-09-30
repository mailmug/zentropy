const std = @import("std");
const KVStore = @import("../KVStore.zig");
const unixSocket = @import("../unixSocket.zig");

// test "unix socket server responds" {
//     var stop: bool = false;
//     const socket_path = "/tmp/zentropy.sock";

//     const thrd = try std.Thread.spawn(.{}, startServer, .{ socket_path, &stop });
//     std.time.sleep(1 * std.time.second);

//     // try client(socket_path);

//     stop = true;
//     try thrd.join();
// }

// fn startServer(allocator: std.mem.Allocator) void {
//     var store = KVStore.init(allocator);

//     unixSocket.startServer(&store) catch |err| {
//         std.debug.print("Server error: {}\n", .{err});
//     };
// }
