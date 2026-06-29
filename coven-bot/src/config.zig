//! config.zig -- config types + JSON loader
const std = @import("std");

pub const MiningDutchConfig = struct {
    api_base_url:   []const u8 = "https://www.mining-dutch.nl/api",
    api_key:        []const u8,
    party_id:       []const u8 = "coven",
    webhook_secret: []const u8,
};

pub const BotConfig = struct {
    discord_webhook_url:              []const u8 = "",
    update_interval_seconds:          u32 = 60,
    alert_threshold_hashrate_drop_percent: f64 = 25.0,
};

pub const WebConfig = struct {
    host:           []const u8 = "0.0.0.0",
    port:           u16 = 8080,
    session_secret: []const u8 = "",
};

pub const DatabaseConfig = struct {
    url:                     []const u8,
    max_connections:         u32 = 10,
    connect_timeout_seconds: u32 = 10,
};

pub const Config = struct {
    mining_dutch: MiningDutchConfig,
    bot:          BotConfig,
    web:          WebConfig,
    database:     DatabaseConfig,

    pub fn loadFromFile(allocator: std.mem.Allocator, path: []const u8) !Config {
        const data = try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 64);
        defer allocator.free(data);
        const parsed = try std.json.parseFromSlice(Config, allocator, data, .{
            .ignore_unknown_fields = true,
        });
        defer parsed.deinit();
        return parsed.value;
    }
};
