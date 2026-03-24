---
name: openflow-skill
description: Snowflake OpenFlow pipeline design, connector configuration, and monitoring for migrating PostgresDB data to Snowflake
---

# OpenFlow Skill — PostgresDB → Snowflake Migration

## Overview

This skill guides building and operating Snowflake OpenFlow pipelines for the **Customer Support Intelligence** project. The goal is to replace the previous NiFi + Kafka stack with a Snowflake-native OpenFlow pipeline that reads `customer_support_tickets` from a PostgresDB instance running in Docker and lands the data into `SUPPORT_INTEL_DB.RAW.CUSTOMER_SUPPORT_TICKETS_2` in Snowflake.

## Project Context

- **OpenFlow Runtime**: `Postgres_db_runtime` — pre-deployed, do not re-create
- **Source**: PostgresDB on Docker (host: `host.docker.internal`, port: `5434`, db: `customer_support_tickets`, table: `customer_support_tickets`)
- **Destination**: Snowflake — `SUPPORT_INTEL_DB.RAW.CUSTOMER_SUPPORT_TICKETS_2`
- **Warehouse**: `SUPPORT_DEV_WH`
- **Role**: `DBT_ROLE` (or `SYSADMIN` for setup)
- **Database**: `SUPPORT_INTEL_DB`
- **Raw Schema**: `RAW`

## When to Use

Invoke this skill when the user asks to:
- Set up or modify OpenFlow pipelines
- Connect to PostgresDB source
- Configure Snowflake destination tables
- Troubleshoot ingestion issues
- Monitor pipeline runs
- Add CDC (change data capture) for incremental loads
- Migrate away from NiFi/Kafka connectors

## Pipeline Design

### Architecture
```
PostgresDB (Docker :5434)
    └──▶ Postgres_db_runtime  (OpenFlow Runtime — pre-deployed)
              └──▶ PostgreSQL Connector  (attach on first run)
                        └──▶ SUPPORT_INTEL_DB.RAW.CUSTOMER_SUPPORT_TICKETS_2
                                  └──▶ dbt (Bronze → Silver → Gold)
```

### Source Table Schema (PostgresDB)
```sql
-- Only body is stored from the HuggingFace dataset.
-- created_at / updated_at drive OpenFlow CDC watermark.
CREATE TABLE customer_support_tickets (
    id          SERIAL      PRIMARY KEY,
    body        TEXT        NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_tickets_updated_at ON customer_support_tickets (updated_at);
CREATE INDEX idx_tickets_body_fts   ON customer_support_tickets USING GIN (to_tsvector('simple', body));
```

### Snowflake RAW Target
```sql
CREATE TABLE IF NOT EXISTS SUPPORT_INTEL_DB.RAW.CUSTOMER_SUPPORT_TICKETS_2 (
    ID                  NUMBER,
    BODY                STRING,
    CREATED_AT          TIMESTAMP_NTZ,
    UPDATED_AT          TIMESTAMP_NTZ,
    _OPENFLOW_LOADED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
```

## OpenFlow Configuration

> **Runtime `Postgres_db_runtime` is already deployed and ready.**
> Do NOT provision a new runtime. Start from Step 1 below.

### Step 1 — Attach PostgreSQL Connector to Existing Runtime
In Snowsight: **Data → OpenFlow → Runtimes → `Postgres_db_runtime` → Add Connector**

| Field | Value |
|-------|-------|
| Connector type | PostgreSQL |
| Host | `host.docker.internal` (Mac) or `172.17.0.1` (Linux) |
| Port | `5434` |
| Database | `customer_support_tickets` |
| Username | `postgres` |
| Password | `postgres123` |
| SSL Mode | `disable` (local Docker) |

Test the connection before proceeding. It must show **Connected** before moving to Step 2.

### Step 2 — Ensure Snowflake RAW Target Table Exists
```sql
-- Run in Snowflake Worksheet (SYSADMIN or DBT_ROLE)
USE DATABASE SUPPORT_INTEL_DB;
USE SCHEMA RAW;

CREATE TABLE IF NOT EXISTS CUSTOMER_SUPPORT_TICKETS_2 (
    ID                  NUMBER,
    BODY                STRING,
    CREATED_AT          TIMESTAMP_NTZ,
    UPDATED_AT          TIMESTAMP_NTZ,
    _OPENFLOW_LOADED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
```

### Step 3 — Configure Pipeline on `Postgres_db_runtime`
In Snowsight: **Data → OpenFlow → Runtimes → `Postgres_db_runtime` → Create Pipeline**

```yaml
# Pipeline configuration (Snowsight UI fields)
runtime:  Postgres_db_runtime

source:
  connector: postgresql           # the connector attached in Step 1
  table: customer_support_tickets
  incremental_column: updated_at
  initial_value: "1970-01-01T00:00:00Z"

destination:
  database: SUPPORT_INTEL_DB
  schema: RAW
  table: CUSTOMER_SUPPORT_TICKETS_2
  write_mode: upsert              # handles re-runs safely
  primary_key: id

schedule: "*/5 * * * *"          # incremental sync every 5 minutes
warehouse: SUPPORT_DEV_WH
```

### Step 4 — Start Migration (Initial Full Load)
Activate the pipeline from the Snowsight UI or via SQL:
```sql
-- Trigger an immediate run to perform the initial full load
ALTER PIPE SUPPORT_INTEL_DB.RAW.OPENFLOW_TICKETS_PIPE REFRESH;
```
Monitor the Snowsight pipeline run log until status shows **Completed** before validating row counts.

## Monitoring

### Check Pipeline Status
```sql
-- View recent pipeline runs
SELECT *
FROM TABLE(INFORMATION_SCHEMA.PIPE_USAGE_HISTORY(
    DATE_RANGE_START => DATEADD('hour', -24, CURRENT_TIMESTAMP()),
    PIPE_NAME => 'SUPPORT_INTEL_DB.RAW.OPENFLOW_TICKETS_PIPE'
))
ORDER BY START_TIME DESC;
```

### Row Count Validation
```sql
-- Source vs destination comparison
SELECT COUNT(*) AS snowflake_count
FROM SUPPORT_INTEL_DB.RAW.CUSTOMER_SUPPORT_TICKETS_2;

-- Check latest loaded record
SELECT MAX(_OPENFLOW_LOADED_AT) AS last_load,
       MAX(UPDATED_AT)          AS last_source_update
FROM SUPPORT_INTEL_DB.RAW.CUSTOMER_SUPPORT_TICKETS_2;
```

### Check for Errors
```sql
SELECT *
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'CUSTOMER_SUPPORT_TICKETS_2',
    START_TIME => DATEADD('hour', -1, CURRENT_TIMESTAMP())
))
WHERE STATUS = 'Load failed';
```

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| Runtime not found | Wrong name | Use exact name `Postgres_db_runtime` — it is pre-deployed |
| Connection refused | Docker network | Use `host.docker.internal:5434` on Mac |
| SSL error | Postgres SSL config | Set `sslmode=disable` for local Docker |
| Schema mismatch | Column type difference | Cast columns explicitly in COPY |
| Duplicate rows | Missing upsert key | Set `primary_key: id` in pipeline |
| Stale data | Watermark not advancing | Verify `updated_at` is indexed in Postgres (`idx_tickets_updated_at`) |
| Connector test fails | Port mismatch | Confirm docker-compose maps `5434:5432` and container is running |

## Best Practices

- Always validate row counts after initial load
- Use `upsert` write mode (not `append`) to handle reprocessing safely
- Index `updated_at` in PostgresDB for efficient incremental scans
- Keep RAW table schema append-only; never transform in RAW
- Add `_OPENFLOW_LOADED_AT` metadata column for lineage tracking
