//! bot.zig -- polling loop, webhook dispatcher, alert engine
const std    = @import("std");
const Config = @import("../config.zig");
const db     = @import("../database.zig");
const api    = @import("api.zig");

const OFFLINE_THRESHOLD_SECONDS: i64 = 300;
const REJECT_RATE_WARN_PCT: f64      = 3.0;
const HASHRATE_DROP_PCT: f64         = 25.0;

pub const Bot = struct {
    allocator:      std.mem.Allocator,
    config:         Config.Config,
    database:       *db.Database,
    api_client:     api.MiningDutchApi,
    running:        bool,
    prev_hashrates: std.StringHashMap(f64),

    pub fn init(allocator: std.mem.Allocator, config: Config.Config, database: *db.Database) !Bot {
        return Bot{
            .allocator      = allocator,
            .config         = config,
            .database       = database,
            .api_client     = try api.MiningDutchApi.init(allocator, config.mining_dutch),
            .running        = false,
            .prev_hashrates = std.StringHashMap(f64).init(allocator),
        };
    }

    pub fn deinit(self: *Bot) void {
        self.api_client.deinit();
        self.prev_hashrates.deinit();
    }

    // -- Main run loop --------------------------------------------------------
    pub fn run(self: *Bot) !void {
        self.running = true;
        std.log.info("Coven bot started. Poll interval: {d}s", .{self.config.bot.update_interval_seconds});
        var tick: u64 = 0;
        while (self.running) {
            self.pollCycle() catch |err| std.log.err("Poll error: {}", .{err});
            tick += 1;
            if (tick % 60 == 0) {
                self.database.rollupHashrateHourly() catch |err| std.log.err("Rollup error: {}", .{err});
            }
            std.time.sleep(@as(u64, self.config.bot.update_interval_seconds) * std.time.ns_per_s);
        }
    }

    pub fn stop(self: *Bot) void { self.running = false; }

    // -- Poll cycle -----------------------------------------------------------
    fn pollCycle(self: *Bot) !void {
        const party = try self.api_client.getPartyStats();
        try self.database.recordPartyStats(
            party.party_id, party.total_hashrate,
            party.active_miners, party.blocks_found_24h, party.estimated_daily_earnings,
        );
        const miners = try self.api_client.getPartyMiners();
        defer self.allocator.free(miners);
        for (miners) |miner| {
            const miner_id = try self.database.upsertMiner(
                miner.worker_name, miner.username, miner.algorithm, miner.region,
            );
            try self.database.updateMinerHashrate(
                miner_id, miner.hashrate, miner.shares_accepted, miner.shares_rejected,
            );
            try self.checkMinerAlerts(miner_id, miner);
        }
        std.log.info("[poll] hashrate={d:.2}MH/s miners={d} blocks_24h={d}", .{
            party.total_hashrate / 1_000_000.0, party.active_miners, party.blocks_found_24h,
        });
    }

    // -- Webhook dispatcher ---------------------------------------------------
    pub fn handleWebhook(self: *Bot, raw_body: []const u8, signature: []const u8) !void {
        if (!self.api_client.verifyWebhookSignature(raw_body, signature)) {
            std.log.warn("Webhook signature mismatch -- rejected", .{});
            return error.InvalidSignature;
        }
        const event_id = try self.database.logWebhookEvent("raw", raw_body);
        var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, raw_body, .{}) catch {
            return error.InvalidJson;
        };
        defer parsed.deinit();
        const root = parsed.value.object;
        const et = (root.get("event_type") orelse return error.MissingEventType).string;
        if (std.mem.eql(u8, et, "block_found"))   try self.onBlockFound(root, event_id)
        else if (std.mem.eql(u8, et, "miner_status"))  try self.onMinerStatus(root, event_id)
        else if (std.mem.eql(u8, et, "share_submitted")) try self.onShareSubmitted(root, event_id)
        else if (std.mem.eql(u8, et, "party_stats"))  try self.onPartyStats(root, event_id)
        else std.log.warn("Unknown webhook event: {s}", .{et});
        try self.database.markWebhookProcessed(event_id);
    }

    // -- Webhook handlers -----------------------------------------------------
    fn onBlockFound(self: *Bot, root: std.json.ObjectMap, _: i64) !void {
        const p = root.get("payload").?.object;
        try self.database.recordBlockFound(
            self.config.mining_dutch.party_id,
            p.get("block_height").?.integer,
            p.get("block_hash").?.string,
            p.get("coin").?.string,
            p.get("algorithm").?.string,
            p.get("reward").?.float,
            p.get("finder_worker").?.string,
        );
        const msg = try std.fmt.allocPrint(self.allocator,
            "BLOCK FOUND by {s} | Coin: {s} | Reward: {d:.4} | Height: {d}",
            .{ p.get("finder_worker").?.string, p.get("coin").?.string,
               p.get("reward").?.float, p.get("block_height").?.integer });
        defer self.allocator.free(msg);
        try self.sendDiscordAlert(msg);
    }

    fn onMinerStatus(self: *Bot, root: std.json.ObjectMap, _: i64) !void {
        const p = root.get("payload").?.object;
        if (!p.get("is_online").?.bool) {
            const msg = try std.fmt.allocPrint(self.allocator,
                "MINER OFFLINE: {s} ({s})",
                .{ p.get("worker_name").?.string, p.get("username").?.string });
            defer self.allocator.free(msg);
            try self.database.createAlert(null, "miner_offline", msg, "warning");
            try self.sendDiscordAlert(msg);
        }
    }

    fn onShareSubmitted(self: *Bot, root: std.json.ObjectMap, _: i64) !void {
        _ = self;
        const p = root.get("payload").?.object;
        if (!p.get("is_valid").?.bool)
            std.log.warn("Invalid share from {s}", .{p.get("worker_name").?.string});
    }

    fn onPartyStats(self: *Bot, root: std.json.ObjectMap, _: i64) !void {
        const p = root.get("payload").?.object;
        try self.database.recordPartyStats(
            p.get("party_id").?.string, p.get("total_hashrate").?.float,
            @intCast(p.get("active_miners").?.integer), 0, 0.0,
        );
    }

    // -- Alert engine ---------------------------------------------------------
    fn checkMinerAlerts(self: *Bot, miner_id: i64, miner: api.MinerInfo) !void {
        const now = std.time.timestamp();

        // Offline check
        if (now - miner.last_share_time > OFFLINE_THRESHOLD_SECONDS) {
            const msg = try std.fmt.allocPrint(self.allocator,
                "Miner {s} has not submitted a share in >5 minutes", .{miner.worker_name});
            defer self.allocator.free(msg);
            try self.database.createAlert(miner_id, "miner_offline", msg, "warning");
        }

        // Reject rate check
        const total = miner.shares_accepted + miner.shares_rejected;
        if (total > 10) {
            const rate = @as(f64, @floatFromInt(miner.shares_rejected)) / @as(f64, @floatFromInt(total)) * 100.0;
            if (rate > REJECT_RATE_WARN_PCT) {
                const msg = try std.fmt.allocPrint(self.allocator,
                    "High reject rate on {s}: {d:.1}%", .{ miner.worker_name, rate });
                defer self.allocator.free(msg);
                try self.database.createAlert(miner_id, "high_reject_rate", msg, "warning");
            }
        }

        // Hashrate drop check
        if (self.prev_hashrates.get(miner.worker_name)) |prev| {
            if (prev > 0.0) {
                const drop = (prev - miner.hashrate) / prev * 100.0;
                if (drop > HASHRATE_DROP_PCT) {
                    const msg = try std.fmt.allocPrint(self.allocator,
                        "Hashrate drop on {s}: {d:.1}% ({d:.2} -> {d:.2} MH/s)",
                        .{ miner.worker_name, drop, prev/1_000_000.0, miner.hashrate/1_000_000.0 });
                    defer self.allocator.free(msg);
                    try self.database.createAlert(miner_id, "hashrate_drop", msg, "warning");
                    try self.sendDiscordAlert(msg);
                }
            }
        }
        try self.prev_hashrates.put(try self.allocator.dupe(u8, miner.worker_name), miner.hashrate);
    }

    // -- Discord notification -------------------------------------------------
    fn sendDiscordAlert(self: *Bot, message: []const u8) !void {
        if (self.config.bot.discord_webhook_url.len == 0) return;
        const body = try std.fmt.allocPrint(self.allocator, "{{\"content\":\"{s}\"}}", .{message});
        defer self.allocator.free(body);
        var client = std.http.Client{ .allocator = self.allocator };
        defer client.deinit();
        var headers = std.http.Headers.init(self.allocator);
        defer headers.deinit();
        try headers.append("Content-Type", "application/json");
        var req = try client.request(.POST, try std.Uri.parse(self.config.bot.discord_webhook_url), headers, .{});
        defer req.deinit();
        req.transfer_encoding = .{ .content_length = body.len };
        try req.start(); try req.writer().writeAll(body); try req.finish(); try req.wait();
        std.log.info("Discord alert sent", .{});
    }
};
