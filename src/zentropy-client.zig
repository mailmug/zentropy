const std = @import("std");
const net = std.net;
const mem = std.mem;
const builtin = @import("builtin");
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

        //check for connectivity only in debug and release safe mod
        switch (builtin.mode) {
            .Debug, .ReleaseSafe => {
                var buf: [32]u8 = undefined;
                var reader = stream.reader(&buf);
                try stream.writeAll("PING"); //TODO replace with writer, writeAll is deprecated
                const expected_result = "+PONG\r\n";
                const pong = try reader.file_reader.interface.takeArray(expected_result.len);

                if (!mem.eql(u8, pong, expected_result)) {
                    return error.BadPingResponse;
                }
            },
            else => {},
        }

        return Client{
            .stream = stream,
        };
    }

    /// destroys connection
    pub fn deinit(self: *const Client) void {
        self.stream.close();
    }

    const SetError = error{
        ServerError,
    } ||
        Io.Writer.Error ||
        Io.Reader.Error;

    pub fn set(self: *Client, key: []const u8, value: []const u8) SetError!void {
        var buf: [4096]u8 = undefined;
        var writer = self.stream.writer(&buf);

        try writer.interface.print("SET {s} {s}", .{ key, value });
        try writer.interface.flush();

        var reader = self.stream.reader(&buf);
        const expected_result = "+OK\r\n";
        const result = try reader.file_reader.interface.takeByte(); // reading only 1 byte for micro boost in performance
        try reader.file_reader.interface.discardAll(expected_result.len - 1); //discarding rest of the result

        if (result != '+') {
            return error.ServerError;
        }
    }
    /// returns result slice pointing in `out`
    pub fn get(self: *Client, key: []const u8, out: []u8) !?[]const u8 {
        _ = .{ self, key, out };
        return null;
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

    const ShutdownError = error{
        BadResponse,
    } || Io.Writer.Error || Io.Reader.Error;

    /// shuts down server
    pub fn shutdown(self: *Client) ShutdownError!void {
        var buf: [32]u8 = undefined;
        var writer = self.stream.writer(&buf);
        try writer.interface.writeAll("SHUTDOWN");
        try writer.interface.flush();

        const expected_result = "===SHUTDOWN===\r\n";

        var reader = self.stream.reader(&buf);
        const result = try reader.file_reader.interface.takeArray(expected_result.len);
        if (!mem.eql(u8, expected_result, result)) {
            return error.BadResponse;
        }
    }
};
