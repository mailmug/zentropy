const std = @import("std");
const posix = std.posix;
const Buffer = @import("Buffer.zig");
const Client = @This();

fd: posix.fd_t,
buffer: Buffer,
authenticated: bool,
fixed_mem: [4096]u8,

pub fn init(fd: posix.fd_t, allocator: std.mem.Allocator) !Client {
    var client = Client{
        .fd = fd,
        .buffer = undefined,
        .authenticated = false,
        .fixed_mem = undefined,
    };

    client.buffer = Buffer.init(&client.fixed_mem, allocator);
    try client.buffer.ensureCapacity(4096);
    return client;
}

pub fn deinit(self: *Client) void {
    self.buffer.deinit();
}
