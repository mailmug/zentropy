const std = @import("std");
const builtin = @import("builtin");
const fs = std.fs;
const posix = std.posix;
const KVStore = @import("KVStore.zig");
const shutdown = @import("shutdown.zig");
const commands = @import("commands.zig");
const Buffer = @import("Buffer.zig");
const Client = @import("Client.zig");

pub fn startServer(store: *KVStore, unix_path: []const u8, stop_server: *std.atomic.Value(bool)) !void {
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

    var clients = std.AutoHashMap(posix.fd_t, Client).init(allocator);
    defer {
        var it = clients.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit();
        }
        clients.deinit();
    }

    // Remove old socket
    _ = fs.cwd().deleteFile(unix_path) catch {};

    const address = try std.net.Address.initUnix(unix_path);

    // Create non-blocking socket manually
    const listener = try posix.socket(posix.AF.UNIX, posix.SOCK.STREAM | posix.SOCK.NONBLOCK, 0);
    defer posix.close(listener);

    // Bind to address
    try posix.bind(listener, &address.any, address.getOsSockLen());
    try posix.listen(listener, 128);

    var polls: [4096]posix.pollfd = undefined;
    polls[0] = .{ .fd = listener, .events = posix.POLL.IN, .revents = 0 };
    var poll_count: usize = 1;

    while (!stop_server.load(.seq_cst)) {
        var active = polls[0..poll_count];
        _ = try posix.poll(active, 100); // 100ms timeout to check stop_server

        if (active[0].revents != 0) {
            const client_fd = try posix.accept(listener, null, null, posix.SOCK.NONBLOCK);

            var client = try Client.init(client_fd, allocator);
            try clients.put(client_fd, client);

            if (poll_count < polls.len) {
                polls[poll_count] = .{
                    .fd = client_fd,
                    .events = posix.POLL.IN,
                    .revents = 0,
                };
                poll_count += 1;
            } else {
                // Handle too many connections
                posix.close(client_fd);
                client.deinit();
            }
        }

        var i: usize = 1;
        while (i < active.len) {
            const polled = active[i];
            const revents = polled.revents;

            if (revents == 0) {
                i += 1;
                continue;
            }

            var close_client = false;

            if (revents & posix.POLL.IN != 0) {
                if (clients.getPtr(polled.fd)) |client| {
                    close_client = try handleClientRead(client);
                    const result = commands.parseCmd(client.fd, store, client.buffer.items());
                    client.buffer.reset();
                    if (result == commands.Command.shutdown) {
                        stop_server.store(true, .seq_cst);
                        shutdown.send("unix_socket") catch {};
                    }
                }
            }

            if (close_client or (revents & (posix.POLL.HUP | posix.POLL.ERR) != 0)) {
                if (clients.fetchRemove(polled.fd)) |entry| {
                    var client = entry.value;
                    client.deinit();
                }
                posix.close(polled.fd);

                const last_index = active.len - 1;
                active[i] = active[last_index];
                active = active[0..last_index];
                poll_count -= 1;
            } else {
                i += 1;
            }
        }
    }
}

fn handleClientRead(client: *Client) !bool {
    while (true) {
        const remaining = client.buffer.data.len - client.buffer.len;
        if (remaining < 512) {
            try client.buffer.ensureCapacity(client.buffer.len + 4096);
        }

        const read_slice = client.buffer.data[client.buffer.len..];
        const read = posix.read(client.fd, read_slice) catch |err| switch (err) {
            error.WouldBlock => break,
            else => return true, // close connection on error
        };

        if (read == 0) break; // EOF

        client.buffer.len += read;
    }

    return false;
}
