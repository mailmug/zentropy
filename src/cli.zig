const std = @import("std");
const config = @import("config.zig");

pub const CliOptions = struct {
    config: ?[]const u8 = null,
    verbose: bool = false,
    start: bool = true,
};

pub fn parse() CliOptions {
    var args_it = std.process.args();
    _ = args_it.next();

    var options = CliOptions{};

    while (args_it.next()) |arg| {
        if (std.mem.eql(u8, arg, "--config")) {
            if (args_it.next()) |value| {
                options.config = value;
            }
        } else if (std.mem.eql(u8, arg, "--version")) {
            options.start = false;
            std.debug.print("{s}", .{config.version});
        }
    }

    return options;
}
