//! api.zig -- Mining-Dutch API client
//! Wraps /api/party and /api/miners endpoints
const std    = @import("std");
const Config = @import("../config.zig");

pub const MinerInfo = struct {
    worker_name:     []const u8,
    username:        []const u8,
    algorithm:       []const u8,
    region:          []const u8,
    hashrate:        f64,
    shares_accepted: i64,
    shares_rejected: i64,
    last_share_time: i64,
};

pub const PartyStats = struct {
    party_id:               []const u8,
    total_hashrate:         f64,
    active_miners:          i32,
    blocks_found_24h:       i32,
    estimated_daily_earnings: f64,
};

pub const MiningDutchApi = struct {
    allocator: std.mem.Allocator,
    config:    Config.MiningDutchConfig,
    client:    std.http.Client,

    pub fn init(allocator: std.mem.Allocator, config: Config.MiningDutchConfig) !MiningDutchApi {
        return MiningDutchApi{
            .allocator = allocator,
            .config    = config,
            .client    = std.http.Client{ .allocator = allocator },
        };
    }

    pub fn deinit(self: *MiningDutchApi) void { self.client.deinit(); }

    // -- GET /api/party -------------------------------------------------------
    pub fn getPartyStats(self: *MiningDutchApi) !PartyStats {
        const url = try std.fmt.allocPrint(self.allocator,
            "{s}/party?party_id={s}&api_key={s}",
            .{ self.config.api_base_url, self.config.party_id, self.config.api_key });
        defer self.allocator.free(url);
        const body = try self.get(url);
        defer self.allocator.free(body);
        var parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, body, .{});
        defer parsed.deinit();
        const r = parsed.value.object;
        return PartyStats{
            .party_id               = try self.allocator.dupe(u8, r.get("party_id").?.string),
            .total_hashrate         = r.get("total_hashrate").?.float,
            .active_miners          = @intCast(r.get("active_miners").?.integer),
            .blocks_found_24h       = @intCast(r.get("blocks_found_24h").?.integer),
            .estimated_daily_earnings = r.get("estimated_daily_earnings").?.float,
        };
    }

    // -- GET /api/miners ------------------------------------------------------
    pub fn getPartyMiners(self: *MiningDutchApi) ![]MinerInfo {
        const url = try std.fmt.allocPrint(self.allocator,
            "{s}/party/miners?party_id={s}&api_key={s}",
            .{ self.config.api_base_url, self.config.party_id, self.config.api_key });
        defer self.allocator.free(url);
        const body = try self.get(url);
        defer self.allocator.free(body);
        var parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, body, .{});
        defer parsed.deinit();
        const arr = parsed.value.array;
        var list  = std.ArrayList(MinerInfo).init(self.allocator);
        for (arr.items) |item| {
            const m = item.object;
            try list.append(MinerInfo{
                .worker_name     = try self.allocator.dupe(u8, m.get("worker_name").?.string),
                .username        = try self.allocator.dupe(u8, m.get("username").?.string),
                .algorithm       = try self.allocator.dupe(u8, m.get("algorithm").?.string),
                .region          = try self.allocator.dupe(u8, (m.get("region") orelse std.json.Value{ .string = "unknown" }).string),
                .hashrate        = m.get("hashrate").?.float,
                .shares_accepted = m.get("shares_accepted").?.integer,
                .shares_rejected = m.get("shares_rejected").?.integer,
                .last_share_time = m.get("last_share_time").?.integer,
            });
        }
        return list.toOwnedSlice();
    }

    // -- Webhook HMAC verification --------------------------------------------
    pub fn verifyWebhookSignature(self: *MiningDutchApi, body: []const u8, signature: []const u8) bool {
        var hmac: [std.crypto.auth.hmac.sha2.HmacSha256.mac_length]u8 = undefined;
        std.crypto.auth.hmac.sha2.HmacSha256.create(&hmac, body, self.config.webhook_secret);
        var hex_buf: [64]u8 = undefined;
        _ = std.fmt.bufPrint(&hex_buf, "{x}", .{std.fmt.fmtSliceHexLower(&hmac)}) catch return false;
        return std.mem.eql(u8, &hex_buf, signature);
    }

    // -- HTTP helper ----------------------------------------------------------
    fn get(self: *MiningDutchApi, url: []const u8) ![]u8 {
        var body = std.ArrayList(u8).init(self.allocator);
        var headers = std.http.Headers.init(self.allocator);
        defer headers.deinit();
        try headers.append("Accept", "application/json");
        try headers.append("User-Agent", "coven-bot/1.0");
        const result = try self.client.fetch(.{
            .location   = .{ .url = url },
            .method     = .GET,
            .headers    = headers,
            .response_storage = .{ .dynamic = &body },
        });
        if (result.status != .ok) {
            std.log.err("API {s} -> HTTP {d}", .{ url, @intFromEnum(result.status) });
            return error.ApiError;
        }
        return body.toOwnedSlice();
    }
};
