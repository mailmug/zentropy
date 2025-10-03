const std = @import("std");
const KVStore = @import("KVStore.zig");
const net = std.net;
const os = std.os;
const posix = std.posix;
const tcp = @This();
const shutdown = @import("shutdown.zig");
const commands = @import("commands.zig");

// pub fn startServer(store: *KVStore, allocator: std.mem.Allocator, stop_server: *std.atomic.Value(bool)) !void {
//     const address = try std.net.Address.parseIp("127.0.0.1", 6383);
//     var listener = try address.listen(.{
//         .reuse_address = true,
//     });
//     defer listener.deinit();

//     while (!stop_server.load(.seq_cst)) {
//         var conn = listener.accept() catch continue;

//         // Read request
//         var buf: [1024]u8 = undefined;
//         const n = conn.stream.read(&buf) catch 0;
//         if (n == 0) continue;

//         const msg = buf[0..n];
//         const result = try handleConnection(conn, store, msg, allocator);

//         if (std.mem.eql(u8, result, "SHUTDOWN")) {
//             stop_server.store(true, .seq_cst);
//             shutdown.send("unix_socket") catch {};
//         }
//         conn.stream.close();
//     }
// }

pub fn startServer(store: *KVStore, stop_server: *std.atomic.Value(bool)) !void {
    const address = try std.net.Address.parseIp("127.0.0.1", 6383);

    const tpe: u32 = posix.SOCK.STREAM | posix.SOCK.NONBLOCK;
    const protocol = posix.IPPROTO.TCP;
    const listener = try posix.socket(address.any.family, tpe, protocol);
    defer posix.close(listener);

    try posix.setsockopt(listener, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
    try posix.setsockopt(listener, posix.SOL.SOCKET, posix.SO.REUSEPORT, &std.mem.toBytes(@as(c_int, 1)));
    try posix.bind(listener, &address.any, address.getOsSockLen());
    try posix.listen(listener, 128);

    // Our server can support 4095 clients. Wait, shouldn't that be 4096? No
    // One of the polling slots (the first one) is reserved for our listening
    // socket.

    var polls: [4096]posix.pollfd = undefined;
    polls[0] = .{
        .fd = listener,
        .events = posix.POLL.IN,
        .revents = 0,
    };
    var poll_count: usize = 1;

    while (!stop_server.load(.seq_cst)) {
        // polls is the total number of connections we can monitor, but
        // polls[0..poll_count] is the actual number of clients + the listening
        // socket that are currently connected
        var active = polls[0..poll_count];

        // 2nd argument is the timeout, -1 is infinity
        _ = try posix.poll(active, -1);

        // Active[0] is _always_ the listening socket. When this socket is ready
        // we can accept. Putting it outside the following while loop means that
        // we don't have to check if if this is the listening socket on each
        // iteration
        if (active[0].revents != 0) {
            // The listening socket is ready, accept!
            // Notice that we pass SOCK.NONBLOCK to accept, placing the new client
            // socket in non-blocking mode. Also, for now, for simplicity,
            // we're not capturing the client address (the two null arguments).
            const socket = try posix.accept(listener, null, null, posix.SOCK.NONBLOCK);

            // Add this new client socket to our polls array for monitoring
            polls[poll_count] = .{
                .fd = socket,

                // This will be SET by posix.poll to tell us what event is ready
                // (or it will stay 0 if this socket isn't ready)
                .revents = 0,

                // We want to be notified about the POLL.IN event
                // (i.e. can read without blocking)
                .events = posix.POLL.IN,
            };

            // increment the number of active connections we're monitoring
            // this can overflow our 4096 polls array. TODO: fix that!
            poll_count += 1;
        }

        var i: usize = 1;
        while (i < active.len) {
            const polled = active[i];

            const revents = polled.revents;
            if (revents == 0) {
                // This socket isn't ready, go to the next one
                i += 1;
                continue;
            }

            var closed = false;

            // the socket is ready to be read
            if (revents & posix.POLL.IN == posix.POLL.IN) {
                var buf: [4096]u8 = undefined;
                const read = posix.read(polled.fd, &buf) catch 0;
                if (read == 0) {
                    // probably closed on the other side
                    closed = true;
                } else {
                    const msg = buf[0..read];
                    const result = try handleConnection(polled.fd, store, msg);
                    if (std.mem.eql(u8, result, "SHUTDOWN")) {
                        stop_server.store(true, .seq_cst);
                        shutdown.send("unix_socket") catch {};
                    }
                }
            }

            // either the read failed, or we're being notified through poll
            // that the socket is closed
            if (closed or (revents & posix.POLL.HUP != 0)) {
                posix.close(polled.fd);

                // We use a simple trick to remove it: we swap it with the last
                // item in our array, then "shrink" our array by 1
                const last_index = active.len - 1;
                active[i] = active[last_index];
                active = active[0..last_index];
                poll_count -= 1;

                // don't increment `i` because we swapped out the removed item
                // and shrank the array
            } else {
                // not closed, go to the next socket
                i += 1;
            }
        }
    }
}

pub fn windowsHandleConnection(conn: std.net.Server.Connection, store: *KVStore, msg: []u8) ![]const u8 {
    return commands.parseCmd(conn, store, msg);
}
pub fn handleConnection(fd: posix.fd_t, store: *KVStore, msg: []u8) ![]const u8 {
    return commands.parseCmd(fd, store, msg);
}
