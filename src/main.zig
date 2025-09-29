const std = @import("std");
const KVStore = @import("KVStore.zig");

pub fn main() !void {
    const gpa = std.heap.page_allocator;
    var store = KVStore.init(gpa);
    defer store.deinit();

    try store.put("apple", "red");
    try store.put("banana", "yellow");

    if (store.get("apple")) |val| {
        std.debug.print("apple => {s}\n", .{val});
    }

    if (store.get("banana")) |val| {
        std.debug.print("banana => {s}\n", .{val});
    }

    if (store.get("cherry")) |val| {
        std.debug.print("cherry => {s}\n", .{val});
    } else {
        std.debug.print("cherry not found\n", .{});
    }

    const removed = store.delete("apple");
    std.debug.print("deleted apple? {}\n", .{removed});
}
