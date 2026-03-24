-- ============================================================
-- Customer Support Tickets — source table for OpenFlow ingestion
-- Only the 'body' column is stored from the HuggingFace dataset.
-- OpenFlow requires 'updated_at' for incremental CDC watermark.
-- ============================================================

CREATE TABLE IF NOT EXISTS customer_support_tickets (
    id          SERIAL          PRIMARY KEY,
    body        TEXT            NOT NULL,
    created_at  TIMESTAMPTZ     DEFAULT NOW(),
    updated_at  TIMESTAMPTZ     DEFAULT NOW()
);

-- Index on updated_at for efficient OpenFlow CDC incremental scans
CREATE INDEX IF NOT EXISTS idx_tickets_updated_at
    ON customer_support_tickets (updated_at);

-- GIN index on body for full-text search
CREATE INDEX IF NOT EXISTS idx_tickets_body_fts
    ON customer_support_tickets
    USING GIN (to_tsvector('simple', body));
