//! web/server.zig -- HTTP server
//! Routes:
//!   POST /webhook              -- Mining-Dutch webhook receiver
//!   GET  /api/party            -- Party overview JSON
//!   GET  /api/miners           -- Active miners JSON
//!   GET  /api/blocks           -- Recent blocks JSON
//!   GET  /api/alerts           -- Active alerts JSON
//!   POST /api/alerts/:id/ack   -- Acknowledge alert
//!   GET  /                     -- Dashboard (index.html)
//!   GET  /static/*             -- Static assets

const std    = @import("std");
const Bot    = @import("../bot/bot.zig").Bot;
const db     = @import("../database.zig");
const Config = @import("../config.zig");

const MAX_BODY     = 1024 * 256;
const STATIC_DIR   = "src/web/static";
const TEMPLATE_DIR = "src/web/templates";

// -- Server -------------------------------------------------------------------
pub const Server = struct {
    allocator: std.mem.Allocator,
    config:    Config.WebConfig,
    bot:       *Bot,
    database:  *db.Database,
    listener:  std.net.Server,

    pub fn init(allocator: std.mem.Allocator, config: Config.WebConfig, bot: *Bot, database: *db.Database) !Server {
        const addr = try std.net.Address.parseIp(config.host, config.port);
        const listener = try addr.listen(.{ .reuse_address = true });
        std.log.info("Web server listening on {s}:{d}", .{ config.host, config.port });
        return Server{ .allocator = allocator, .config = config, .bot = bot, .database = database, .listener = listener };
    }

    pub fn deinit(self: *Server) void { self.listener.deinit(); }

    pub fn run(self: *Server) !void {
        while (true) {
            const conn = try self.listener.accept();
            const ctx  = try self.allocator.create(ConnCtx);
            ctx.* = .{ .server = self, .conn = conn };
            const t = try std.Thread.spawn(.{}, handleConn, .{ctx});
            t.detach();
        }
    }
};

const ConnCtx = struct { server: *Server, conn: std.net.Server.Connection };

fn handleConn(ctx: *ConnCtx) void {
    defer { ctx.conn.stream.close(); ctx.server.allocator.destroy(ctx); }
    serveRequest(ctx.server, ctx.conn.stream) catch |err|
        std.log.err("Request error: {}", .{err});
}

// -- Router -------------------------------------------------------------------
fn serveRequest(server: *Server, stream: std.net.Stream) !void {
    var buf: [8192]u8 = undefined;
    var http_server = std.http.Server.init(stream, &buf);
    var req = try http_server.receiveHead();
    const method = req.head.method;
    const target = req.head.target;
    std.log.info("{s} {s}", .{ @tagName(method), target });

    if (method == .POST and std.mem.eql(u8, target, "/webhook"))          return handleWebhook(server, &req);
    if (method == .GET  and std.mem.eql(u8, target, "/api/party"))        return handleApiParty(server, &req);
    if (method == .GET  and std.mem.eql(u8, target, "/api/miners"))       return handleApiMiners(server, &req);
    if (method == .GET  and std.mem.eql(u8, target, "/api/blocks"))       return handleApiBlocks(server, &req);
    if (method == .GET  and std.mem.eql(u8, target, "/api/alerts"))       return handleApiAlerts(server, &req);
    if (method == .POST and std.mem.startsWith(u8, target, "/api/alerts/")) return handleAckAlert(server, &req, target);
    if (method == .GET  and std.mem.eql(u8, target, "/"))                 return serveFile(server, &req, TEMPLATE_DIR ++ "/index.html", "text/html");
    if (method == .GET  and std.mem.startsWith(u8, target, "/static/"))   return serveStatic(server, &req, target);

    try req.respond("Not Found", .{ .status = .not_found,
        .extra_headers = &.{.{ .name = "Content-Type", .value = "text/plain" }} });
}

// -- POST /webhook ------------------------------------------------------------
fn handleWebhook(server: *Server, req: *std.http.Server.Request) !void {
    const body = try req.reader().readAllAlloc(server.allocator, MAX_BODY);
    defer server.allocator.free(body);
    var sig: []const u8 = "";
    var it = req.iterateHeaders();
    while (it.next()) |h| {
        if (std.ascii.eqlIgnoreCase(h.name, "x-signature")) { sig = h.value; break; }
    }
    server.bot.handleWebhook(body, sig) catch {
        try req.respond("Bad Request", .{ .status = .bad_request }); return;
    };
    try req.respond("OK", .{ .status = .ok,
        .extra_headers = &.{.{ .name = "Content-Type", .value = "text/plain" }} });
}

// -- GET /api/party -----------------------------------------------------------
fn handleApiParty(server: *Server, req: *std.http.Server.Request) !void {
    var out = std.ArrayList(u8).init(server.allocator); defer out.deinit();
    const w = out.writer();
    if (try server.database.getPartyOverview(server.bot.config.mining_dutch.party_id)) |r| {
        try w.print("{{\"party_id\":\"{s}\",\"total_hashrate\":{d:.4},\"active_miners\":{d},\"blocks_found\":{d},\"estimated_earnings\":{d:.8},\"last_updated\":{d}}}",
            .{ r.party_id, r.total_hashrate, r.active_miners, r.blocks_found, r.estimated_earnings, r.last_updated });
    } else try w.writeAll("{}");
    try jsonReply(req, out.items);
}

// -- GET /api/miners ----------------------------------------------------------
fn handleApiMiners(server: *Server, req: *std.http.Server.Request) !void {
    const miners = try server.database.getActiveMiners(); defer server.allocator.free(miners);
    var out = std.ArrayList(u8).init(server.allocator); defer out.deinit();
    const w = out.writer();
    try w.writeByte('[');
    for (miners, 0..) |m, i| {
        if (i > 0) try w.writeByte(',');
        try w.print("{{\"id\":{d},\"worker_name\":\"{s}\",\"username\":\"{s}\",\"algorithm\":\"{s}\",\"region\":\"{s}\",\"is_online\":{s},\"hashrate\":{d:.4},\"accepted\":{d},\"rejected\":{d},\"last_seen\":{d}}}",
            .{ m.id, m.worker_name, m.username, m.algorithm, m.region,
               if (m.is_online) "true" else "false",
               m.current_hashrate, m.shares_accepted, m.shares_rejected, m.last_seen });
    }
    try w.writeByte(']');
    try jsonReply(req, out.items);
}

// -- GET /api/blocks ----------------------------------------------------------
fn handleApiBlocks(server: *Server, req: *std.http.Server.Request) !void {
    const blocks = try server.database.getRecentBlocks(server.bot.config.mining_dutch.party_id, 20);
    defer server.allocator.free(blocks);
    var out = std.ArrayList(u8).init(server.allocator); defer out.deinit();
    const w = out.writer();
    try w.writeByte('[');
    for (blocks, 0..) |b, i| {
        if (i > 0) try w.writeByte(',');
        try w.print("{{\"id\":{d},\"block_height\":{d},\"block_hash\":\"{s}\",\"coin\":\"{s}\",\"algorithm\":\"{s}\",\"reward\":{d:.8},\"found_at\":{d},\"finder\":\"{s}\"}}",
            .{ b.id, b.block_height, b.block_hash, b.coin, b.algorithm, b.reward, b.found_at, b.finder_worker });
    }
    try w.writeByte(']');
    try jsonReply(req, out.items);
}

// -- GET /api/alerts ----------------------------------------------------------
fn handleApiAlerts(server: *Server, req: *std.http.Server.Request) !void {
    const alerts = try server.database.getActiveAlerts(); defer server.allocator.free(alerts);
    var out = std.ArrayList(u8).init(server.allocator); defer out.deinit();
    const w = out.writer();
    try w.writeByte('[');
    for (alerts, 0..) |a, i| {
        if (i > 0) try w.writeByte(',');
        try w.print("{{\"id\":{d},\"alert_type\":\"{s}\",\"message\":\"{s}\",\"severity\":\"{s}\",\"created_at\":{d}}}",
            .{ a.id, a.alert_type, a.message, a.severity, a.created_at });
    }
    try w.writeByte(']');
    try jsonReply(req, out.items);
}

// -- POST /api/alerts/:id/ack -------------------------------------------------
fn handleAckAlert(server: *Server, req: *std.http.Server.Request, target: []const u8) !void {
    const prefix = "/api/alerts/";
    const suffix = "/ack";
    if (!std.mem.endsWith(u8, target, suffix)) {
        try req.respond("Not Found", .{ .status = .not_found }); return;
    }
    const id_str = target[prefix.len .. target.len - suffix.len];
    const alert_id = std.fmt.parseInt(i64, id_str, 10) catch {
        try req.respond("Bad Request", .{ .status = .bad_request }); return;
    };
    try server.database.acknowledgeAlert(alert_id);
    try jsonReply(req, "{\"ok\":true}");
}

// -- Static file server -------------------------------------------------------
fn serveStatic(server: *Server, req: *std.http.Server.Request, target: []const u8) !void {
    const rel  = target["/static/".len..];
    const path = try std.fmt.allocPrint(server.allocator, "{s}/{s}", .{ STATIC_DIR, rel });
    defer server.allocator.free(path);
    return serveFile(server, req, path, mimeType(rel));
}

fn serveFile(server: *Server, req: *std.http.Server.Request, path: []const u8, mime: []const u8) !void {
    const content = std.fs.cwd().readFileAlloc(server.allocator, path, 1024*1024) catch {
        try req.respond("Not Found", .{ .status = .not_found }); return;
    };
    defer server.allocator.free(content);
    try req.respond(content, .{ .extra_headers = &.{.{ .name = "Content-Type", .value = mime }} });
}

fn mimeType(f: []const u8) []const u8 {
    if (std.mem.endsWith(u8, f, ".js"))   return "application/javascript";
    if (std.mem.endsWith(u8, f, ".css"))  return "text/css";
    if (std.mem.endsWith(u8, f, ".html")) return "text/html";
    if (std.mem.endsWith(u8, f, ".json")) return "application/json";
    return "application/octet-stream";
}

fn jsonReply(req: *std.http.Server.Request, body: []const u8) !void {
    try req.respond(body, .{ .extra_headers = &.{
        .{ .name = "Content-Type",                .value = "application/json" },
        .{ .name = "Access-Control-Allow-Origin", .value = "*" },
        .{ .name = "Cache-Control",               .value = "no-cache" },
    }});
}
