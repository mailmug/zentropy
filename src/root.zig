const std = @import("std");

test {
    _ = @import("tests/KVStoreTests.zig");
    _ = @import("tests/tcpTests.zig");
    _ = @import("tests/unixSocketTest.zig");
}
