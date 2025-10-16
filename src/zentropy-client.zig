const std = @import("std");
const Allocator = std.mem.Allocator;
const Config = @import("config.zig");

/// wrapper for connecting with Zentropy server
pub const Client = struct {
    ///connects to the server with `config` parameters
    pub fn connect(config: Config) !Client {}

    /// destroys connection
    pub fn deinit(self: *Client) void {}

    pub fn set(self: *Client, key: []const u8, value: []const u8) !void {}
    /// returns bytes read
    pub fn get(self: *Client, key: []const u8, out: []u8) !?usize {}

    /// caller owns memory
    pub fn getAlloc(self: *Client, gpa: Allocator, key: []const u8) !?[]u8 {}

    /// returns comptime known size string
    pub fn getSized(self: *Client, key: []const u8, comptime size: comptime_int) !?[size]u8 {}

    /// checks if key exists
    pub fn exists(self: *Client, key: []const u8) !bool {}

    /// deletes key, if key doesn't exists returns error.KeyNotFound
    pub fn delete(self: *Client, key: []const u8) !bool {}

    /// shuts down server
    pub fn shutdown(self: *Client) !void {}
};
