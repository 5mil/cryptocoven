-- 001_initial.sql — Crypto Coven Bot — Neon Postgres schema

-- ── Miners ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS miners (
    id           BIGSERIAL PRIMARY KEY,
    worker_name  TEXT UNIQUE NOT NULL,
    username     TEXT NOT NULL,
    algorithm    TEXT NOT NULL,
    region       TEXT NOT NULL DEFAULT 'unknown',
    first_seen   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_active    BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE INDEX IF NOT EXISTS idx_miners_username ON miners(username);
CREATE INDEX IF NOT EXISTS idx_miners_algorithm ON miners(algorithm);

-- ── Raw hashrate history (7-day TTL, rolled up hourly) ────────────────────────
CREATE TABLE IF NOT EXISTS hashrate_history (
    id               BIGSERIAL PRIMARY KEY,
    miner_id         BIGINT NOT NULL REFERENCES miners(id) ON DELETE CASCADE,
    ts               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    hashrate         FLOAT8 NOT NULL DEFAULT 0,
    shares_accepted  BIGINT NOT NULL DEFAULT 0,
    shares_rejected  BIGINT NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_hashrate_history_miner_ts ON hashrate_history(miner_id, ts DESC);

-- ── Hourly rollup (permanent retention) ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS hashrate_hourly (
    miner_id        BIGINT NOT NULL REFERENCES miners(id) ON DELETE CASCADE,
    hour_bucket     TIMESTAMPTZ NOT NULL,
    avg_hashrate    FLOAT8 NOT NULL DEFAULT 0,
    total_accepted  BIGINT NOT NULL DEFAULT 0,
    total_rejected  BIGINT NOT NULL DEFAULT 0,
    PRIMARY KEY (miner_id, hour_bucket)
);

-- ── Party stats snapshots ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS party_stats (
    id                  BIGSERIAL PRIMARY KEY,
    party_id            TEXT NOT NULL,
    ts                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    total_hashrate      FLOAT8 NOT NULL DEFAULT 0,
    active_miners       INT NOT NULL DEFAULT 0,
    blocks_found        INT NOT NULL DEFAULT 0,
    estimated_earnings  FLOAT8 NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_party_stats_party_ts ON party_stats(party_id, ts DESC);

-- ── Blocks found ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS blocks_found (
    id              BIGSERIAL PRIMARY KEY,
    party_id        TEXT NOT NULL,
    block_height    BIGINT NOT NULL,
    block_hash      TEXT NOT NULL,
    coin            TEXT NOT NULL,
    algorithm       TEXT NOT NULL,
    reward          FLOAT8 NOT NULL DEFAULT 0,
    found_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    finder_worker   TEXT
);
CREATE INDEX IF NOT EXISTS idx_blocks_party_found ON blocks_found(party_id, found_at DESC);

-- ── Webhook events ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS webhook_events (
    id            BIGSERIAL PRIMARY KEY,
    event_type    TEXT NOT NULL,
    payload       JSONB NOT NULL,
    received_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed     BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS idx_webhook_payload_gin ON webhook_events USING GIN(payload);
CREATE INDEX IF NOT EXISTS idx_webhook_received ON webhook_events(received_at DESC);

-- ── Alerts ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS alerts (
    id            BIGSERIAL PRIMARY KEY,
    miner_id      BIGINT REFERENCES miners(id) ON DELETE SET NULL,
    alert_type    TEXT NOT NULL,
    message       TEXT NOT NULL,
    severity      TEXT NOT NULL DEFAULT 'info',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    acknowledged  BOOLEAN NOT NULL DEFAULT FALSE,
    ack_at        TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_alerts_unacked ON alerts(created_at DESC) WHERE acknowledged = FALSE;

-- ── Views ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW miner_status AS
SELECT
    m.id, m.worker_name, m.username, m.algorithm, m.region, m.last_seen,
    (m.last_seen > NOW() - INTERVAL '5 minutes') AS is_online,
    COALESCE(h.hashrate, 0)          AS current_hashrate,
    COALESCE(h.shares_accepted, 0)   AS shares_accepted,
    COALESCE(h.shares_rejected, 0)   AS shares_rejected
FROM miners m
LEFT JOIN LATERAL (
    SELECT hashrate, shares_accepted, shares_rejected
    FROM hashrate_history
    WHERE miner_id = m.id
    ORDER BY ts DESC LIMIT 1
) h ON TRUE
WHERE m.is_active = TRUE;

CREATE OR REPLACE VIEW party_overview AS
SELECT DISTINCT ON (party_id)
    party_id, total_hashrate, active_miners, blocks_found,
    estimated_earnings, ts AS last_updated
FROM party_stats
ORDER BY party_id, ts DESC;

CREATE OR REPLACE VIEW active_alerts AS
SELECT id, miner_id, alert_type, message, severity, created_at
FROM alerts
WHERE acknowledged = FALSE
ORDER BY created_at DESC;
