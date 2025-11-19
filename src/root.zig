const std = @import("std");

pub const Client = @import("zentropy-client.zig").Client;

test {
    _ = @import("tests/KVStoreTests.zig");
    _ = @import("tests/tcpTests.zig");
    _ = @import("tests/unixSocketTest.zig");
    _ = @import("tests/clientTest.zig");
}
