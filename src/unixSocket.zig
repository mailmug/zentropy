const std = @import("std");
const fs = std.fs;
const posix = std.posix;
const KVStore = @import("KVStore.zig");
const tcp = @import("tcp.zig");
const shutdown = @import("shutdown.zig");
const commands = @import("commands.zig");

pub fn startServer(store: *KVStore, unix_path: []const u8, stop_server: *std.atomic.Value(bool)) !void {
    // Remove old socket
    _ = fs.cwd().deleteFile(unix_path) catch {};

    const address = try std.net.Address.initUnix(unix_path);

    // Create non-blocking socket manually
    const listener_fd = try posix.socket(posix.AF.UNIX, posix.SOCK.STREAM | posix.SOCK.NONBLOCK, 0);
    defer posix.close(listener_fd);

    // Bind to address
    try posix.bind(listener_fd, &address.any, address.getOsSockLen());
    try posix.listen(listener_fd, 128);

    // Set up polling
    var polls: [4096]posix.pollfd = undefined;
    polls[0] = .{
        .fd = listener_fd,
        .events = posix.POLL.IN,
        .revents = 0,
    };
    var poll_count: usize = 1;

    while (!stop_server.load(.seq_cst)) {
        var active = polls[0..poll_count];

        // Poll with 100ms timeout to check stop_server periodically
        _ = posix.poll(active, 100) catch |err| {
            if (err == error.Interrupted) continue;
            return err;
        };

        // Handle new connections
        if (active[0].revents != 0) {
            while (true) {
                const client_fd = posix.accept(listener_fd, null, null, posix.SOCK.NONBLOCK) catch |err| switch (err) {
                    error.WouldBlock => break, // No more pending connections
                    else => |e| return e,
                };

                if (poll_count < polls.len) {
                    polls[poll_count] = .{
                        .fd = client_fd,
                        .events = posix.POLL.IN,
                        .revents = 0,
                    };
                    poll_count += 1;
                } else {
                    posix.close(client_fd);
                }
            }
        }

        // Handle client connections
        var i: usize = 1;
        while (i < poll_count) {
            const polled = &active[i];
            var closed = false;

            if (polled.revents & posix.POLL.IN != 0) {
                var buf: [1024]u8 = undefined;
                const n = posix.read(polled.fd, &buf) catch 0;

                if (n == 0) {
                    closed = true;
                } else {
                    const msg = buf[0..n];

                    // Create a stream from the file descriptor for handleConnection
                    const result = handleConnection(polled.fd, store, msg) catch {
                        closed = true;
                        continue;
                    };

                    if (std.mem.eql(u8, result, "SHUTDOWN")) {
                        stop_server.store(true, .seq_cst);
                    }
                }
            }

            // Handle errors and hangup
            if (closed or (polled.revents & (posix.POLL.HUP | posix.POLL.ERR) != 0)) {
                posix.close(polled.fd);

                // Remove from polls array
                const last_index = poll_count - 1;
                if (i < last_index) {
                    polls[i] = polls[last_index];
                }
                poll_count -= 1;
                // Don't increment i since we swapped
            } else {
                i += 1;
            }
        }
    }

    // Cleanup
    for (polls[1..poll_count]) |polled| {
        posix.close(polled.fd);
    }
    fs.cwd().deleteFile(unix_path) catch {};
}

pub fn handleConnection(fd: posix.fd_t, store: *KVStore, msg: []u8) ![]const u8 {
    return commands.parseCmd(fd, store, msg);
}
