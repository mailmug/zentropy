const std = @import("std");
const posix = std.posix;
const Buffer = @import("Buffer.zig");
const Client = @This();

fd: posix.fd_t,
buffer: Buffer,
authenticated: bool,

pub fn init(fd: posix.fd_t, allocator: std.mem.Allocator) !Client {
    var fixed_mem: [4096]u8 = undefined;
    var buffer = Buffer.init(&fixed_mem, allocator);
    try buffer.ensureCapacity(4096);
    return Client{
        .fd = fd,
        .buffer = buffer,
        .authenticated = false,
    };
}

pub fn deinit(self: *Client) void {
    self.buffer.deinit();
}
