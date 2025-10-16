const std = @import("std");
const Config = @This();

bind_address: []const u8 = "127.0.0.1",
port: u16 = 6383,
password: ?[]const u8 = null,

pub fn load(allocator: std.mem.Allocator) !Config {
    const possible_paths = &[_][]const u8{
        "./zentropy.conf", // Current directory
        "zentropy.conf", // Current directory
        "../zentropy.conf", // Parent directory
        "config/zentropy.conf", // config subdirectory
        "/etc/zentropy/zentropy.conf", // System config directory
    };

    const exe_dir = try std.fs.selfExeDirPathAlloc(allocator);
    defer allocator.free(exe_dir);

    const full_path = try std.fs.path.join(allocator, &[_][]const u8{ exe_dir, "zentropy.conf" });
    defer allocator.free(full_path);

    if (fileExists(full_path)) {
        return loadFromFile(allocator, full_path);
    }

    for (possible_paths) |path| {
        if (fileExists(path)) {
            return loadFromFile(allocator, path);
        }
    }

    std.log.warn("No configuration file found. Using defaults.", .{});
    return .{};
}

fn fileExists(file_path: []const u8) bool {
    std.fs.cwd().access(file_path, .{}) catch return false;
    return true;
}

pub fn loadFromFile(allocator: std.mem.Allocator, file_path: []const u8) !Config {
    var config = Config{};

    const file = std.fs.cwd().openFile(file_path, .{}) catch |err| {
        std.log.warn("Could not open config file '{s}': {s}. Using defaults.", .{ file_path, @errorName(err) });
        return config;
    };
    defer file.close();

    const file_size = try file.getEndPos();
    const file_content = try allocator.alloc(u8, file_size);
    defer allocator.free(file_content);

    _ = try file.readAll(file_content);

    var lines = std.mem.splitSequence(u8, file_content, "\n");
    var line_num: u32 = 0;

    while (lines.next()) |line| {
        line_num += 1;
        const trimmed_line = std.mem.trim(u8, line, " \t\r");

        // Skip empty lines and comments
        if (trimmed_line.len == 0 or trimmed_line[0] == '#') {
            continue;
        }

        // Parse key-value pairs
        if (std.mem.indexOf(u8, trimmed_line, " ")) |eq_index| {
            const key = std.mem.trim(u8, trimmed_line[0..eq_index], " \t");
            const value = std.mem.trim(u8, trimmed_line[eq_index + 1 ..], " \t\"'");

            if (std.mem.eql(u8, key, "bind_address") and !std.mem.eql(u8, value, "127.0.0.1")) {
                config.bind_address = try allocator.dupe(u8, value);
            } else if (std.mem.eql(u8, key, "port")) {
                config.port = std.fmt.parseInt(u16, value, 10) catch {
                    std.log.warn("Invalid port value '{s}' on line {d}. Using default port {d}.", .{ value, line_num, config.port });
                    continue;
                };
            } else if (std.mem.eql(u8, key, "password") and !std.mem.eql(u8, value, "null")) {
                config.password = try allocator.dupe(u8, value);
            }
        }
    }

    return config;
}

pub fn deinit(self: *Config, allocator: std.mem.Allocator) void {
    if (!std.mem.eql(u8, self.bind_address, "127.0.0.1")) {
        allocator.free(self.bind_address);
    }
    if (self.password) |pwd| {
        allocator.free(pwd);
    }
}
