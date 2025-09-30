const std = @import("std");

test {
    _ = @import("tests/kvStoreTests.zig");
    _ = @import("tests/tcpTests.zig");
    _ = @import("tests/unixSocket.zig");
}
