//! main.zig -- Coven Bot entry point
//! Usage:
//!   coven-bot  <config.json>   -- runs bot + web server (both threads)
const std    = @import("std");
const Config = @import("config.zig");
const db     = @import("database.zig");
const Bot    = @import("bot/bot.zig").Bot;
const Server = @import("web/server.zig").Server;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len < 2) {
        std.log.err("Usage: {s} <config.json>", .{args[0]});
        return error.MissingArgs;
    }

    const config = try Config.Config.loadFromFile(allocator, args[1]);
    std.log.info("Loaded config: party={s} port={d}", .{ config.mining_dutch.party_id, config.web.port });

    var database = try db.Database.init(allocator, .{
        .url             = config.database.url,
        .max_connections = config.database.max_connections,
        .connect_timeout_seconds = config.database.connect_timeout_seconds,
    });
    defer database.deinit();

    var bot = try Bot.init(allocator, config, &database);
    defer bot.deinit();

    var web = try Server.init(allocator, config.web, &bot, &database);
    defer web.deinit();

    const bot_thread = try std.Thread.spawn(.{}, Bot.run, .{&bot});
    bot_thread.detach();

    std.log.info("Coven Bot running. Ctrl+C to stop.", .{});
    try web.run();
}
