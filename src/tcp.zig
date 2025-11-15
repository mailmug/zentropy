const std = @import("std");
const builtin = @import("builtin");
const KVStore = @import("KVStore.zig");
const net = std.net;
const os = std.os;
const posix = std.posix;
const tcp = @This();
const shutdown = @import("shutdown.zig");
const commands = @import("commands.zig");
const Config = @import("config.zig");
const Buffer = @import("Buffer.zig");
const Client = @import("Client.zig");

pub fn startServer(store: *KVStore, stop_server: *std.atomic.Value(bool), app_config: *const Config) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = if (builtin.mode == .Debug) gpa.allocator() else std.heap.page_allocator;

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
            const client = entry.value_ptr; // *Client
            client.deinit();
        }
        clients.deinit();
    }

    const address = try std.net.Address.parseIp(app_config.bind_address, app_config.port);
    const listener = try posix.socket(address.any.family, posix.SOCK.STREAM | posix.SOCK.NONBLOCK, posix.IPPROTO.TCP);
    defer posix.close(listener);

    try posix.setsockopt(listener, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
    try posix.setsockopt(listener, posix.SOL.SOCKET, posix.SO.REUSEPORT, &std.mem.toBytes(@as(c_int, 1)));
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
                    const result = handleConnection(client, store, client.buffer.items(), app_config);
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

pub fn handleConnection(client: *Client, store: *KVStore, msg: []u8, app_config: *const Config) ?commands.Command {
    if (std.mem.startsWith(u8, msg, "AUTH ")) {
        const pass = trimCrlf(msg[5..]);
        if (app_config.password != null and std.mem.eql(u8, pass, app_config.password.?)) {
            client.authenticated = true;
            // clients.put(client.fd, client.*) catch {};
            _ = posix.write(client.fd, "+OK\r\n") catch {};
        } else {
            _ = posix.write(client.fd, "-ERR invalid password\r\n") catch {};
        }
        return null;
    }

    if (app_config.password != null) {
        if (!client.authenticated) {
            _ = posix.write(client.fd, "-NOAUTH Authentication required\r\n") catch {};
            return null;
        }
    }
    return commands.parseCmd(client.fd, store, msg);
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

fn trimCrlf(s: []u8) []u8 {
    var end: usize = 0;
    while (end < s.len and s[end] != '\r' and s[end] != '\n') : (end += 1) {}
    return s[0..end];
}
