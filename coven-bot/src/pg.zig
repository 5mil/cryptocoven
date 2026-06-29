//! pg.zig -- libpq C bindings + connection pool
//! Build: -lc -lpq  |  Neon: sslmode=require in URL
const std = @import("std");

pub const c = @cImport({ @cInclude("libpq-fe.h"); });

// -- Conn ---------------------------------------------------------------------
pub const Conn = struct {
    pg: *c.PGconn,

    pub fn connect(conninfo: [*:0]const u8) !Conn {
        const pg = c.PQconnectdb(conninfo) orelse return error.OutOfMemory;
        if (c.PQstatus(pg) != c.CONNECTION_OK) {
            std.log.err("connect failed: {s}", .{c.PQerrorMessage(pg)});
            c.PQfinish(pg);
            return error.ConnectionFailed;
        }
        std.log.info("Neon connected (PID {})", .{c.PQbackendPID(pg)});
        return Conn{ .pg = pg };
    }

    pub fn deinit(self: Conn) void { c.PQfinish(self.pg); }
    pub fn isAlive(self: Conn) bool { return c.PQstatus(self.pg) == c.CONNECTION_OK; }
    pub fn reset(self: Conn) !void {
        c.PQreset(self.pg);
        if (c.PQstatus(self.pg) != c.CONNECTION_OK) return error.ReconnectFailed;
    }

    pub fn exec(self: Conn, sql: [*:0]const u8, params: []const [*:0]const u8) !Result {
        const res = c.PQexecParams(
            self.pg, sql, @intCast(params.len), null,
            @ptrCast(params.ptr), null, null, 0,
        ) orelse return error.OutOfMemory;
        const status = c.PQresultStatus(res);
        if (status != c.PGRES_TUPLES_OK and status != c.PGRES_COMMAND_OK) {
            std.log.err("query failed: {s}", .{c.PQresultErrorMessage(res)});
            c.PQclear(res);
            return error.QueryFailed;
        }
        return Result{ .res = res };
    }

    pub fn execSimple(self: Conn, sql: [*:0]const u8) !Result { return self.exec(sql, &.{}); }

    pub fn queryScalar(self: Conn, alloc: std.mem.Allocator, sql: [*:0]const u8, params: []const [*:0]const u8) ![]u8 {
        var r = try self.exec(sql, params); defer r.deinit();
        if (r.rows() == 0) return error.NoRows;
        const val = r.get(0, 0) orelse return error.NullValue;
        return alloc.dupe(u8, std.mem.span(val));
    }
};

// -- Result -------------------------------------------------------------------
pub const Result = struct {
    res: *c.PGresult,
    pub fn deinit(self: Result) void { c.PQclear(self.res); }
    pub fn rows(self: Result) usize { return @intCast(c.PQntuples(self.res)); }
    pub fn cols(self: Result) usize { return @intCast(c.PQnfields(self.res)); }
    pub fn get(self: Result, row: usize, col: usize) ?[*:0]const u8 {
        if (c.PQgetisnull(self.res, @intCast(row), @intCast(col)) == 1) return null;
        return c.PQgetvalue(self.res, @intCast(row), @intCast(col));
    }
    pub fn getString(self: Result, row: usize, col: usize) []const u8 {
        return if (self.get(row, col)) |v| std.mem.span(v) else "";
    }
    pub fn getInt(self: Result, comptime T: type, row: usize, col: usize) !T {
        return std.fmt.parseInt(T, self.getString(row, col), 10);
    }
    pub fn getFloat(self: Result, comptime T: type, row: usize, col: usize) !T {
        return std.fmt.parseFloat(T, self.getString(row, col));
    }
    pub fn getBool(self: Result, row: usize, col: usize) bool {
        const s = self.getString(row, col);
        return s.len > 0 and (s[0] == 't' or s[0] == '1');
    }
};

// -- Pool ---------------------------------------------------------------------
pub const Pool = struct {
    conns:     []Conn,
    available: std.ArrayList(usize),
    mutex:     std.Thread.Mutex,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, conninfo: [:0]const u8, size: u32) !Pool {
        var conns = try allocator.alloc(Conn, size);
        var available = std.ArrayList(usize).init(allocator);
        for (0..size) |i| { conns[i] = try Conn.connect(conninfo.ptr); try available.append(i); }
        return Pool{ .conns = conns, .available = available, .mutex = .{}, .allocator = allocator };
    }
    pub fn deinit(self: *Pool) void {
        for (self.conns) |conn| conn.deinit();
        self.allocator.free(self.conns); self.available.deinit();
    }
    pub fn acquire(self: *Pool) !*Conn {
        while (true) {
            self.mutex.lock();
            if (self.available.items.len > 0) {
                const idx = self.available.pop(); self.mutex.unlock();
                const conn = &self.conns[idx];
                if (!conn.isAlive()) try conn.reset();
                return conn;
            }
            self.mutex.unlock();
            std.time.sleep(1 * std.time.ns_per_ms);
        }
    }
    pub fn release(self: *Pool, conn: *Conn) void {
        const idx = (@intFromPtr(conn) - @intFromPtr(self.conns.ptr)) / @sizeOf(Conn);
        self.mutex.lock(); defer self.mutex.unlock();
        self.available.append(idx) catch {};
    }
};

// -- Helpers ------------------------------------------------------------------
pub fn buildConninfo(alloc: std.mem.Allocator, url: []const u8) ![:0]u8 {
    return std.fmt.allocPrintZ(alloc, "{s}", .{url});
}
pub fn escapeLiteral(alloc: std.mem.Allocator, conn: Conn, s: []const u8) ![]u8 {
    const e = c.PQescapeLiteral(conn.pg, s.ptr, s.len) orelse return error.OutOfMemory;
    defer c.PQfreemem(e);
    return alloc.dupe(u8, std.mem.span(e));
}
