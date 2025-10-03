const std = @import("std");
const KVStore = @import("../KVStore.zig");

test "KVStore basic operations" {
    const allocator = std.testing.allocator;
    var store = KVStore.init(allocator);

    defer store.deinit();

    try store.set("apple", "red");
    try store.set("banana", "yellow");
    try store.set("grape", "purple");

    // Get values
    const apple = store.get("apple") orelse "";
    const banana = store.get("banana") orelse "";
    const grape = store.get("grape") orelse "";

    try std.testing.expectEqualStrings(apple, "red");
    try std.testing.expectEqualStrings(banana, "yellow");
    try std.testing.expectEqualStrings(grape, "purple");

    // Delete key
    try std.testing.expect(store.delete("banana"));
    try std.testing.expect(!store.delete("nonexistent"));

    // Confirm deletion
    const banana_after = store.get("banana");
    try std.testing.expect(banana_after == null);
}

test "KVStore save/load persistence" {
    const allocator = std.testing.allocator;
    var store = KVStore.init(allocator);
    defer store.deinit();

    // // Add some key/value pairs
    try store.set("apple", "red");
    try store.set("banana", "yellow");
    try store.set("grape", "purple");

    // Save to file
    try store.saveToFile("data.bin");

    // Clear the map
    // store.deinit();
    store.map.clearAndFree(allocator);

    // Confirm map is empty
    try std.testing.expect(store.get("apple") == null);
    try std.testing.expect(store.get("banana") == null);
    try std.testing.expect(store.get("grape") == null);

    // Load from file
    try store.loadFromFile("data.bin");

    const apple = store.get("apple") orelse "";
    const banana = store.get("banana") orelse "";
    const grape = store.get("grape") orelse "";

    try std.testing.expectEqualStrings(apple, "red");
    try std.testing.expectEqualStrings(banana, "yellow");
    try std.testing.expectEqualStrings(grape, "purple");

    // Delete a key and check
    try std.testing.expect(store.delete("banana"));
    try std.testing.expect(!store.delete("nonexistent"));

    const banana_after = store.get("banana");
    try std.testing.expect(banana_after == null);

    // Clean up test file
    try std.fs.cwd().deleteFile("data.bin");
}
