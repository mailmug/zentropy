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

    const buffer_size = 4096; // this affects responses max size

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

        //check for connectivity only in debug and release safe mode
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
        var buf: [buffer_size]u8 = undefined;
        var writer = self.stream.writer(&buf);

        try writer.interface.print("SET \"{s}\" \"{s}\"", .{ key, value });
        try writer.interface.flush();

        var reader = self.stream.reader(&buf);
        const result = try reader.file_reader.interface.takeByte(); // reading only 1 byte for micro boost in performance
        try reader.file_reader.interface.discardAll(responses.ok.len - 1); //discarding rest of the result

        if (result != '+') {
            return error.ServerError;
        }
    }
    /// returns result slice pointing in `out`
    pub fn get(self: *Client, key: []const u8, out: []u8) !?[]u8 {
        var buf: [buffer_size]u8 = undefined;
        var writer = self.stream.writer(&buf);

        try writer.interface.print("GET \"{s}\"", .{key});
        try writer.interface.flush();

        var reader = self.stream.reader(out);

        const peek = try reader.file_reader.interface.peek(responses.none.len);
        if (mem.eql(u8, peek, responses.none)) {
            try reader.file_reader.interface.discardAll(responses.none.len);
            return null;
        }
        const slice = try reader.file_reader.interface.takeDelimiter('\r');
        try reader.file_reader.interface.discardAll(1); //discard "\n"

        return slice;
    }

    /// caller owns memory
    pub fn getAlloc(self: *Client, gpa: Allocator, key: []const u8) !?[]u8 {
        var buf: [buffer_size]u8 = undefined;
        var writer = self.stream.writer(&buf);

        try writer.interface.print("GET \"{s}\"", .{key});
        try writer.interface.flush();

        var reader = self.stream.reader(&buf);
        const peek = try reader.file_reader.interface.peek(responses.none.len);
        if (mem.eql(u8, peek, responses.none)) {
            try reader.file_reader.interface.discardAll(responses.none.len);
            return null;
        }
        const slice = try reader.file_reader.interface.takeDelimiter('\r') orelse return null;
        try reader.file_reader.interface.discardAll(1); //discard "\n"

        return try gpa.dupe(u8, slice);
    }

    /// returns comptime known size string
    pub fn getSized(self: *Client, key: []const u8, comptime size: comptime_int) !?[size]u8 {
        var buf: [buffer_size]u8 = undefined;
        var writer = self.stream.writer(&buf);

        try writer.interface.print("GET \"{s}\"", .{key});
        try writer.interface.flush();

        var reader = self.stream.reader(&buf);

        const peek = try reader.file_reader.interface.peek(responses.none.len);
        if (mem.eql(u8, peek, responses.none)) {
            try reader.file_reader.interface.discardAll(responses.none.len);
            return null;
        }

        const result = try reader.file_reader.interface.takeArray(size);
        var output: [result.len]u8 = undefined;
        output = result.*;
        _ = try reader.file_reader.interface.discardShort(2); //discard "\r\n"

        return output;
    }

    /// checks if key exists
    pub fn exists(self: *Client, key: []const u8) !bool {
        var buf: [buffer_size]u8 = undefined;
        var writer = self.stream.writer(&buf);

        try writer.interface.print("EXISTS \"{s}\"", .{key});
        try writer.interface.flush();

        var reader = self.stream.reader(&buf);
        const exists_byte = try reader.file_reader.interface.takeByte();
        try reader.file_reader.interface.discardAll(2); //discard "\r\n"

        return if (exists_byte == '1') true else false;
    }

    /// deletes key, returns true if deleted
    pub fn delete(self: *Client, key: []const u8) !bool {
        var buf: [buffer_size]u8 = undefined;
        var writer = self.stream.writer(&buf);

        try writer.interface.print("DELETE \"{s}\"", .{key});
        try writer.interface.flush();

        var reader = self.stream.reader(&buf);

        const peek = try reader.file_reader.interface.peek(responses.ok.len);
        if (mem.eql(u8, peek, responses.ok)) {
            try reader.file_reader.interface.discardAll(responses.ok.len);
            return true;
        }
        try reader.file_reader.interface.discardAll(responses.not_deleted.len);
        return false;
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

        var reader = self.stream.reader(&buf);
        const result = try reader.file_reader.interface.takeArray(responses.shutdown.len);
        if (!mem.eql(u8, responses.shutdown, result)) {
            return error.BadResponse;
        }
    }
};

const responses = struct {
    pub const shutdown = "===SHUTDOWN===\r\n";
    pub const ok = "+OK\r\n";
    pub const not_deleted = "-NOT DELETED\r\n";
    pub const none = "NONE\r\n";
};
