const std = @import("std");
const net = std.net;
const mem = std.mem;
const Io = std.Io;
const Reader = Io.Reader;
const Stream = net.Stream;
const Allocator = std.mem.Allocator;
const Config = @import("config.zig");

/// wrapper for connecting with Zentropy server
pub const Client = struct {
    stream: net.Stream,

    const ConnectError = error{
        BadPingResponse,
    } ||
        net.TcpConnectToAddressError ||
        Stream.WriteError ||
        Reader.Error ||
        net.IPv4ParseError;

    ///connects to the server with `config` parameters
    pub fn connect(config: Config) ConnectError!Client {
        const stream = try net.tcpConnectToAddress(.{
            .in = try .parse(config.bind_address, config.port),
        });

        var reader = stream.reader(&[_]u8{});
        try stream.writeAll("PING");
        const pong = try reader.file_reader.interface.takeArray(4);

        if (!mem.eql(u8, pong, "PONG")) {
            return error.BadPingResponse;
        }

        return Client{
            .stream = stream,
        };
    }

    /// destroys connection
    pub fn deinit(self: *const Client) void {
        self.stream.close();
    }

    pub fn set(self: *Client, key: []const u8, value: []const u8) !void {
        _ = .{ self, key, value };
    }
    /// returns bytes read
    pub fn get(self: *Client, key: []const u8, out: []u8) !?usize {
        _ = .{ self, key, out };
    }

    /// caller owns memory
    pub fn getAlloc(self: *Client, gpa: Allocator, key: []const u8) !?[]u8 {
        _ = .{ self, gpa, key };
    }

    /// returns comptime known size string
    pub fn getSized(self: *Client, key: []const u8, comptime size: comptime_int) !?[size]u8 {
        _ = .{ self, key, size };
    }

    /// checks if key exists
    pub fn exists(self: *Client, key: []const u8) !bool {
        _ = .{ self, key };
    }

    /// deletes key, if key doesn't exists returns error.KeyNotFound
    pub fn delete(self: *Client, key: []const u8) !bool {
        _ = .{ self, key };
    }

    /// shuts down server
    pub fn shutdown(self: *Client) !void {
        _ = self;
    }
};
