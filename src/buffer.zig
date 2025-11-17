const std = @import("std");
const Buffer = @This();

fba: std.heap.FixedBufferAllocator,
fallback: std.mem.Allocator,
allocator: std.mem.Allocator,
data: []u8,
len: usize,
using_fba: bool,
multi_size: usize,
multi_size_str: []u8,

pub fn init(fixed_mem: []u8, fallback: std.mem.Allocator) Buffer {
    var fba = std.heap.FixedBufferAllocator.init(fixed_mem);
    return .{
        .fba = fba,
        .fallback = fallback,
        .allocator = fba.allocator(),
        .data = fixed_mem, // empty slice backed by fixed buffer
        .len = 0,
        .using_fba = true,
        .multi_size = 0,
        .multi_size_str = "",
    };
}

fn switchToFallback(self: *Buffer) !void {
    const needed = self.data.len + 14096;
    const current_len = self.data.len;
    const min_capacity = @max(needed, current_len);

    const new_capacity = if (min_capacity < 1024 * 1024)
        @max(min_capacity, current_len) * 2 // Double until 1MB
    else
        min_capacity + 1024 * 1024;

    const new_data = try self.fallback.alloc(u8, new_capacity);
    @memcpy(new_data[0..self.len], self.data[0..self.len]);
    self.data = new_data;
    self.allocator = self.fallback;
    self.using_fba = false;
}

pub fn ensureCapacity(self: *Buffer, needed: usize) !void {
    if (needed <= self.data.len) return;

    if (self.using_fba) {
        try self.switchToFallback();
        return;
    }

    const new_data = try self.allocator.realloc(self.data, needed);
    self.data = new_data;
}

pub fn append(self: *Buffer, bytes: []const u8) !void {
    try self.ensureCapacity(self.len + bytes.len);
    @memcpy(self.data[self.len..][0..bytes.len], bytes);
    self.len += bytes.len;
}

pub fn clear(self: *Buffer) void {
    self.len = 0;
}

pub fn items(self: Buffer) []u8 {
    return self.data[0..self.len];
}

pub fn deinit(self: *Buffer) void {
    if (!self.using_fba) {
        self.fallback.free(self.data);
    }
}

pub fn reset(self: *Buffer) void {
    self.deinit();
    self.fba.reset();
    self.data = self.fba.buffer[0..0];
    self.allocator = self.fba.allocator();
    self.using_fba = true;
    self.len = 0;
}
