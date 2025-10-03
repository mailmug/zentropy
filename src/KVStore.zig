const std = @import("std");

pub const KVStore = @This();

allocator: std.mem.Allocator,

// Use AutoHashMap for automatic sizing
map: std.StringHashMapUnmanaged(Entry) = .{},

// Memory pool for key/value storage
arena: std.heap.ArenaAllocator,

const Entry = struct {
    value: []const u8,
};

pub fn init(allocator: std.mem.Allocator) KVStore {
    var self = KVStore{
        .allocator = allocator,
        .arena = std.heap.ArenaAllocator.init(allocator),
    };

    // Pre-allocate some capacity
    self.map.ensureTotalCapacity(allocator, 10000) catch unreachable;

    return self;
}

pub fn deinit(self: *KVStore) void {
    self.map.deinit(self.allocator);
    self.arena.deinit();
}

pub fn set(self: *KVStore, key: []const u8, value: []const u8) !void {
    const arena = self.arena.allocator();

    // Copy strings to arena
    const key_copy = try arena.dupe(u8, key);
    const value_copy = try arena.dupe(u8, value);

    const entry = Entry{ .value = value_copy };

    // Use getOrPut to handle both new and existing keys
    const gop = try self.map.getOrPut(self.allocator, key_copy);
    if (!gop.found_existing) {
        gop.key_ptr.* = key_copy;
    }
    gop.value_ptr.* = entry;
}

pub fn get(self: *KVStore, key: []const u8) ?[]const u8 {
    if (self.map.getPtr(key)) |entry| {
        return entry.value;
    }
    return null;
}

pub fn contains(self: *KVStore, key: []const u8) bool {
    return self.map.contains(key);
}
pub fn count(self: *KVStore) usize {
    return self.map.count();
}

pub fn delete(self: *KVStore, key: []const u8) bool {
    const removed = self.map.remove(key);
    if (removed) {
        return true;
    }
    return false;
}

pub fn saveToFile(self: *KVStore, path: []const u8) !void {
    var file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var it = self.map.iterator();
    while (it.next()) |entry| {
        // key
        const key = entry.key_ptr.*;
        const key_len_buf = KVStore.toByteSize(key.len);
        try file.writeAll(key_len_buf[0..]);
        try file.writeAll(key);

        // value
        const val = entry.value_ptr.value;
        const val_len_buf = KVStore.toByteSize(val.len);
        try file.writeAll(val_len_buf[0..]);
        try file.writeAll(val);
    }
}

pub fn loadFromFile(self: *KVStore, path: []const u8) !void {
    const fs = std.fs;
    var file = try fs.cwd().openFile(path, .{});
    defer file.close();

    var len_buf: [4]u8 = undefined;

    while (true) {
        const bytes_read = try file.read(len_buf[0..]);
        if (bytes_read == 0) break; // EOF
        if (bytes_read != 4) return error.InvalidFormat;

        const key_len = KVStore.getSize(len_buf);
        const key_buf = try self.arena.allocator().alloc(u8, key_len);
        _ = try file.readAll(key_buf);

        _ = try file.readAll(len_buf[0..]);
        const val_len = KVStore.getSize(len_buf);
        const val_buf = try self.arena.allocator().alloc(u8, val_len);
        _ = try file.readAll(val_buf);

        // Store slices owned by arena
        try self.set(key_buf, val_buf);
    }
}

fn getSize(len_buf: [4]u8) usize {
    const len_1: usize = @intCast(len_buf[0]);
    const len_2: usize = @intCast(len_buf[1]);
    const len_3: usize = @intCast(len_buf[2]);
    const len_4: usize = @intCast(len_buf[3]);

    const len: usize = len_1 | len_2 << 8 | len_3 << 16 | len_4 << 24;

    return len;
}

fn toByteSize(len: usize) [4]u8 {
    var len_buf: [4]u8 = undefined;
    len_buf[0] = @intCast(len & 0xFF);
    len_buf[1] = @intCast((len >> 8) & 0xFF);
    len_buf[2] = @intCast((len >> 16) & 0xFF);
    len_buf[3] = @intCast((len >> 24) & 0xFF);
    return len_buf;
}
