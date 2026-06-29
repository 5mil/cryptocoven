//! database.zig -- all SQL queries wired to Neon via pg.zig pool
const std = @import("std");
const pg  = @import("pg.zig");

pub const PgConfig = struct {
    url: []const u8,
    max_connections: u32 = 10,
    connect_timeout_seconds: u32 = 10,
};

pub const Database = struct {
    allocator: std.mem.Allocator,
    pool: pg.Pool,

    pub fn init(allocator: std.mem.Allocator, config: PgConfig) !Database {
        const conninfo = try pg.buildConninfo(allocator, config.url);
        defer allocator.free(conninfo);
        const pool = try pg.Pool.init(allocator, conninfo, config.max_connections);
        return Database{ .allocator = allocator, .pool = pool };
    }
    pub fn deinit(self: *Database) void { self.pool.deinit(); }

    fn z(self: *Database, comptime fmt: []const u8, args: anytype) ![*:0]u8 {
        return std.fmt.allocPrintZ(self.allocator, fmt, args);
    }

    // -- Miners ---------------------------------------------------------------
    pub fn upsertMiner(self: *Database, worker_name: []const u8, username: []const u8, algorithm: []const u8, region: []const u8) !i64 {
        const conn = try self.pool.acquire(); defer self.pool.release(conn);
        const p1 = try self.z("{s}", .{worker_name}); defer self.allocator.free(p1);
        const p2 = try self.z("{s}", .{username});    defer self.allocator.free(p2);
        const p3 = try self.z("{s}", .{algorithm});   defer self.allocator.free(p3);
        const p4 = try self.z("{s}", .{region});      defer self.allocator.free(p4);
        var r = try conn.exec(
            "INSERT INTO miners (worker_name,username,algorithm,region,first_seen,last_seen) " ++
            "VALUES ($1,$2,$3,$4,NOW(),NOW()) ON CONFLICT (worker_name) DO UPDATE " ++
            "SET last_seen=NOW(),is_active=TRUE RETURNING id",
            &.{p1,p2,p3,p4});
        defer r.deinit();
        return r.getInt(i64, 0, 0);
    }

    pub fn updateMinerHashrate(self: *Database, miner_id: i64, hashrate: f64, accepted: i64, rejected: i64) !void {
        const conn = try self.pool.acquire(); defer self.pool.release(conn);
        const p1 = try self.z("{d}",    .{miner_id}); defer self.allocator.free(p1);
        const p2 = try self.z("{d:.4}", .{hashrate}); defer self.allocator.free(p2);
        const p3 = try self.z("{d}",    .{accepted}); defer self.allocator.free(p3);
        const p4 = try self.z("{d}",    .{rejected}); defer self.allocator.free(p4);
        var r = try conn.exec(
            "INSERT INTO hashrate_history (miner_id,ts,hashrate,shares_accepted,shares_rejected) " ++
            "VALUES ($1::bigint,NOW(),$2::float8,$3::bigint,$4::bigint)",
            &.{p1,p2,p3,p4});
        r.deinit();
    }

    pub fn getActiveMiners(self: *Database) ![]MinerRow {
        const conn = try self.pool.acquire(); defer self.pool.release(conn);
        var r = try conn.execSimple(
            "SELECT id,worker_name,username,algorithm,region," ++
            "extract(epoch from last_seen)::bigint,is_online," ++
            "COALESCE(current_hashrate,0),COALESCE(shares_accepted,0),COALESCE(shares_rejected,0) " ++
            "FROM miner_status ORDER BY worker_name ASC");
        defer r.deinit();
        var list = std.ArrayList(MinerRow).init(self.allocator);
        for (0..r.rows()) |i| {
            try list.append(.{
                .id               = try r.getInt(i64, i, 0),
                .worker_name      = try self.allocator.dupe(u8, r.getString(i, 1)),
                .username         = try self.allocator.dupe(u8, r.getString(i, 2)),
                .algorithm        = try self.allocator.dupe(u8, r.getString(i, 3)),
                .region           = try self.allocator.dupe(u8, r.getString(i, 4)),
                .last_seen        = try r.getInt(i64, i, 5),
                .is_online        = r.getBool(i, 6),
                .current_hashrate = try r.getFloat(f64, i, 7),
                .shares_accepted  = try r.getInt(i64, i, 8),
                .shares_rejected  = try r.getInt(i64, i, 9),
            });
        }
        return list.toOwnedSlice();
    }

    // -- Party stats ----------------------------------------------------------
    pub fn recordPartyStats(self: *Database, party_id: []const u8, total_hashrate: f64, active_miners: i32, blocks_found: i32, estimated_earnings: f64) !void {
        const conn = try self.pool.acquire(); defer self.pool.release(conn);
        const p1 = try self.z("{s}",    .{party_id});          defer self.allocator.free(p1);
        const p2 = try self.z("{d:.4}", .{total_hashrate});    defer self.allocator.free(p2);
        const p3 = try self.z("{d}",    .{active_miners});     defer self.allocator.free(p3);
        const p4 = try self.z("{d}",    .{blocks_found});      defer self.allocator.free(p4);
        const p5 = try self.z("{d:.8}", .{estimated_earnings}); defer self.allocator.free(p5);
        var r = try conn.exec(
            "INSERT INTO party_stats (party_id,ts,total_hashrate,active_miners,blocks_found,estimated_earnings) " ++
            "VALUES ($1,NOW(),$2::float8,$3::int,$4::int,$5::float8)",
            &.{p1,p2,p3,p4,p5});
        r.deinit();
    }

    pub fn getPartyOverview(self: *Database, party_id: []const u8) !?PartyOverviewRow {
        const conn = try self.pool.acquire(); defer self.pool.release(conn);
        const p1 = try self.z("{s}", .{party_id}); defer self.allocator.free(p1);
        var r = try conn.exec(
            "SELECT party_id,total_hashrate,active_miners,blocks_found," ++
            "estimated_earnings,extract(epoch from last_updated)::bigint " ++
            "FROM party_overview WHERE party_id=$1", &.{p1});
        defer r.deinit();
        if (r.rows() == 0) return null;
        return .{
            .party_id           = try self.allocator.dupe(u8, r.getString(0, 0)),
            .total_hashrate     = try r.getFloat(f64, 0, 1),
            .active_miners      = try r.getInt(i32, 0, 2),
            .blocks_found       = try r.getInt(i32, 0, 3),
            .estimated_earnings = try r.getFloat(f64, 0, 4),
            .last_updated       = try r.getInt(i64, 0, 5),
        };
    }

    // -- Blocks ---------------------------------------------------------------
    pub fn recordBlockFound(self: *Database, party_id: []const u8, block_height: i64, block_hash: []const u8, coin: []const u8, algorithm: []const u8, reward: f64, finder_worker: ?[]const u8) !void {
        const conn = try self.pool.acquire(); defer self.pool.release(conn);
        const p1 = try self.z("{s}",    .{party_id});    defer self.allocator.free(p1);
        const p2 = try self.z("{d}",    .{block_height}); defer self.allocator.free(p2);
        const p3 = try self.z("{s}",    .{block_hash});  defer self.allocator.free(p3);
        const p4 = try self.z("{s}",    .{coin});        defer self.allocator.free(p4);
        const p5 = try self.z("{s}",    .{algorithm});   defer self.allocator.free(p5);
        const p6 = try self.z("{d:.8}", .{reward});      defer self.allocator.free(p6);
        const p7 = try self.z("{s}",    .{finder_worker orelse ""}); defer self.allocator.free(p7);
        var r = try conn.exec(
            "INSERT INTO blocks_found (party_id,block_height,block_hash,coin,algorithm,reward,found_at,finder_worker) " ++
            "VALUES ($1,$2::bigint,$3,$4,$5,$6::float8,NOW(),NULLIF($7,''))",
            &.{p1,p2,p3,p4,p5,p6,p7});
        r.deinit();
    }

    pub fn getRecentBlocks(self: *Database, party_id: []const u8, limit: i32) ![]BlockRow {
        const conn = try self.pool.acquire(); defer self.pool.release(conn);
        const p1 = try self.z("{s}", .{party_id}); defer self.allocator.free(p1);
        const p2 = try self.z("{d}", .{limit});    defer self.allocator.free(p2);
        var r = try conn.exec(
            "SELECT id,party_id,block_height,block_hash,coin,algorithm,reward," ++
            "extract(epoch from found_at)::bigint,COALESCE(finder_worker,'') " ++
            "FROM blocks_found WHERE party_id=$1 ORDER BY found_at DESC LIMIT $2",
            &.{p1,p2});
        defer r.deinit();
        var list = std.ArrayList(BlockRow).init(self.allocator);
        for (0..r.rows()) |i| {
            try list.append(.{
                .id            = try r.getInt(i64, i, 0),
                .party_id      = try self.allocator.dupe(u8, r.getString(i, 1)),
                .block_height  = try r.getInt(i64, i, 2),
                .block_hash    = try self.allocator.dupe(u8, r.getString(i, 3)),
                .coin          = try self.allocator.dupe(u8, r.getString(i, 4)),
                .algorithm     = try self.allocator.dupe(u8, r.getString(i, 5)),
                .reward        = try r.getFloat(f64, i, 6),
                .found_at      = try r.getInt(i64, i, 7),
                .finder_worker = try self.allocator.dupe(u8, r.getString(i, 8)),
            });
        }
        return list.toOwnedSlice();
    }

    // -- Webhooks -------------------------------------------------------------
    pub fn logWebhookEvent(self: *Database, event_type: []const u8, payload_json: []const u8) !i64 {
        const conn = try self.pool.acquire(); defer self.pool.release(conn);
        const p1 = try self.z("{s}", .{event_type});    defer self.allocator.free(p1);
        const p2 = try self.z("{s}", .{payload_json}); defer self.allocator.free(p2);
        var r = try conn.exec(
            "INSERT INTO webhook_events (event_type,payload,received_at) VALUES ($1,$2::jsonb,NOW()) RETURNING id",
            &.{p1,p2});
        defer r.deinit();
        return r.getInt(i64, 0, 0);
    }
    pub fn markWebhookProcessed(self: *Database, event_id: i64) !void {
        const conn = try self.pool.acquire(); defer self.pool.release(conn);
        const p1 = try self.z("{d}", .{event_id}); defer self.allocator.free(p1);
        var r = try conn.exec("UPDATE webhook_events SET processed=TRUE WHERE id=$1", &.{p1}); r.deinit();
    }

    // -- Alerts ---------------------------------------------------------------
    pub fn createAlert(self: *Database, miner_id: ?i64, alert_type: []const u8, message: []const u8, severity: []const u8) !void {
        const conn = try self.pool.acquire(); defer self.pool.release(conn);
        const p1 = if (miner_id) |id| try self.z("{d}", .{id}) else try self.z("", .{}); defer self.allocator.free(p1);
        const p2 = try self.z("{s}", .{alert_type}); defer self.allocator.free(p2);
        const p3 = try self.z("{s}", .{message});    defer self.allocator.free(p3);
        const p4 = try self.z("{s}", .{severity});   defer self.allocator.free(p4);
        var r = try conn.exec(
            "INSERT INTO alerts (miner_id,alert_type,message,severity,created_at) VALUES (NULLIF($1,'')::bigint,$2,$3,$4,NOW())",
            &.{p1,p2,p3,p4}); r.deinit();
    }
    pub fn getActiveAlerts(self: *Database) ![]AlertRow {
        const conn = try self.pool.acquire(); defer self.pool.release(conn);
        var r = try conn.execSimple(
            "SELECT id,miner_id,alert_type,message,severity,extract(epoch from created_at)::bigint FROM active_alerts LIMIT 50");
        defer r.deinit();
        var list = std.ArrayList(AlertRow).init(self.allocator);
        for (0..r.rows()) |i| {
            try list.append(.{
                .id         = try r.getInt(i64, i, 0),
                .miner_id   = if (r.get(i, 1) == null) null else try r.getInt(i64, i, 1),
                .alert_type = try self.allocator.dupe(u8, r.getString(i, 2)),
                .message    = try self.allocator.dupe(u8, r.getString(i, 3)),
                .severity   = try self.allocator.dupe(u8, r.getString(i, 4)),
                .created_at = try r.getInt(i64, i, 5),
            });
        }
        return list.toOwnedSlice();
    }
    pub fn acknowledgeAlert(self: *Database, alert_id: i64) !void {
        const conn = try self.pool.acquire(); defer self.pool.release(conn);
        const p1 = try self.z("{d}", .{alert_id}); defer self.allocator.free(p1);
        var r = try conn.exec("UPDATE alerts SET acknowledged=TRUE,ack_at=NOW() WHERE id=$1", &.{p1}); r.deinit();
    }

    // -- Rollup ---------------------------------------------------------------
    pub fn rollupHashrateHourly(self: *Database) !void {
        const conn = try self.pool.acquire(); defer self.pool.release(conn);
        var r1 = try conn.execSimple(
            "INSERT INTO hashrate_hourly (miner_id,hour_bucket,avg_hashrate,total_accepted,total_rejected) " ++
            "SELECT miner_id,date_trunc('hour',ts),AVG(hashrate),SUM(shares_accepted),SUM(shares_rejected) " ++
            "FROM hashrate_history WHERE ts < NOW()-INTERVAL '1 hour' " ++
            "GROUP BY miner_id,date_trunc('hour',ts) ON CONFLICT (miner_id,hour_bucket) DO NOTHING"); r1.deinit();
        var r2 = try conn.execSimple("DELETE FROM hashrate_history WHERE ts < NOW()-INTERVAL '7 days'"); r2.deinit();
        std.log.info("hourly rollup complete", .{});
    }
};

// -- Row types ----------------------------------------------------------------
pub const MinerRow = struct {
    id: i64, worker_name: []u8, username: []u8, algorithm: []u8, region: []u8,
    last_seen: i64, is_online: bool, current_hashrate: f64,
    shares_accepted: i64, shares_rejected: i64,
};
pub const PartyOverviewRow = struct {
    party_id: []u8, total_hashrate: f64, active_miners: i32,
    blocks_found: i32, estimated_earnings: f64, last_updated: i64,
};
pub const BlockRow = struct {
    id: i64, party_id: []u8, block_height: i64, block_hash: []u8,
    coin: []u8, algorithm: []u8, reward: f64, found_at: i64, finder_worker: []u8,
};
pub const AlertRow = struct {
    id: i64, miner_id: ?i64, alert_type: []u8,
    message: []u8, severity: []u8, created_at: i64,
};
