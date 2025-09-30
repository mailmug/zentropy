const std = @import("std");
const shutdown = @This();

pub fn send(to: []const u8) !void {
    if (std.mem.eql(u8, to, "tcp")) {
        const address = try std.net.Address.parseIp4("127.0.0.1", 6383);
        var conn = try std.net.tcpConnectToAddress(address);
        defer conn.close();
    }
    if (std.mem.eql(u8, to, "unix_socket")) {
        const socket_path = "/tmp/zentropy.sock";
        var conn = try std.net.connectUnixSocket(socket_path);
        defer conn.close();
    }
}
