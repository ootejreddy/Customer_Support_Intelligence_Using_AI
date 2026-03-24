---
name: dbt-skill
description: dbt model authoring, incremental builds, Snowflake Cortex AI SQL functions, testing, and Snowflake optimization for the Customer Support Intelligence medallion pipeline — with emphasis on good dbt practices, single-responsibility models, and YML-driven configuration
---

# dbt Skill — Medallion Pipeline with Snowflake Cortex AI

## Project Context

| Setting | Value |
|---------|-------|
| Project path | `dbt/customer_support_dbt` |
| Profiles path | `dbt/customer_support_dbt/profiles.yml` |
| Database | `SUPPORT_INTEL_DB` |
| Schemas | `BRONZE`, `SILVER`, `GOLD` |
| Warehouse | `SUPPORT_DEV_WH` |
| Auth | Key-pair (`~/.snowflake/rsa_key.p8`) |

## When to Use

Invoke this skill when the user asks to:
- Create or modify dbt models (Bronze, Silver, Gold)
- Add Snowflake Cortex AI enrichment to Silver models
- Configure incremental materialization for OpenFlow CDC data
- Write dbt tests, macros, or sources YAML
- Debug dbt failures or optimize Snowflake queries

---

## Core Principle: One Model, One Job

Every model does **one thing**. Never stack multiple Cortex AI functions in a single model or CTE chain. Each transformation concern gets its own file. This makes models:
- Easy to debug (you can `dbt run --select` just that step)
- Cheap to re-run (re-run only the failing Cortex call, not all four)
- Easy to read (no 150-line Silver model)

### The layered Silver approach for this project

```
bronze_tickets_extracted           ← type-cast, filter nulls (Bronze)
        │
        ▼
stg_tickets_translated             ← CORTEX.TRANSLATE only
        │
        ▼
stg_tickets_classified             ← CORTEX.CLASSIFY_TEXT only
        │
        ▼
stg_tickets_sentiment              ← CORTEX.SENTIMENT + label derivation
        │
        ▼
silver_tickets_enriched            ← CORTEX.COMPLETE (priority) + final assembly
        │
        ▼
mart_tickets_dashboard             ← Gold: add UI columns, sort order
```

Each arrow is a `{{ ref() }}`. No model does two different Cortex calls.

---

## Materialization: Configure in `dbt_project.yml`, Not in Models

Do NOT put `config(materialized=...)` in every SQL file. Set defaults by folder in `dbt_project.yml` and only override in properties YML when a single model differs.

### `dbt_project.yml` pattern
```yaml
models:
  customer_support_dbt:
    bronze:
      +materialized: view          # Bronze is always a view — cheap, always fresh
    silver:
      +materialized: incremental   # Silver models are incremental by default
      +unique_key: ticket_id
      +incremental_strategy: merge
      +on_schema_change: append_new_columns
    gold:
      +materialized: table         # Gold is a table for fast dashboard queries
```

A model only adds a `{{ config() }}` block when it **deviates** from the folder default.

---

## Naming Conventions: Defined in YML, Not in SQL

Column aliases and descriptions live in `properties.yml` — not embedded in SQL as comments or long alias chains.

### What goes in YML
- Column descriptions
- Test definitions (`unique`, `not_null`, `accepted_values`, `not_empty_string`)
- `meta` tags (owner, sensitivity, pii)
- `config` overrides per model

### What stays in SQL
- Logic (CASE, JOINs, filters)
- Column aliases only when the source name is genuinely different from what the business wants

### Good: clean SQL, rich YML
```sql
-- stg_tickets_translated.sql
select
    ticket_id,
    language,
    subject,
    body,
    case
        when lower(language) != 'en' and subject is not null and trim(subject) != ''
            then {{ cortex_translate('subject', 'language') }}
        else subject
    end as subject_english,
    case
        when lower(language) != 'en' and body is not null and trim(body) != ''
            then {{ cortex_translate('body', 'language') }}
        else body
    end as body_english,
    created_at,
    updated_at
from {{ ref('bronze_tickets_extracted') }}
```

```yaml
# properties.yml — column descriptions belong here
- name: stg_tickets_translated
  description: Translates non-English ticket text to English using Cortex TRANSLATE.
  columns:
    - name: subject_english
      description: Subject translated to English. Same as subject when language is 'en'.
    - name: body_english
      description: Body translated to English. Same as body when language is 'en'.
```

### Bad: descriptions buried in SQL aliases
```sql
-- Don't do this
select
    body_english as body_english__translated_to_english_by_cortex,
    ...
```

---

## Macros: Wrap Cortex Functions, Don't Inline Them

Cortex function calls are long and repeated. Put them in macros so they're maintainable in one place.

### `macros/cortex_functions.sql`

```sql
{# Translate a column to English. Accepts column name as string. #}
{% macro cortex_translate(text_col, lang_col) %}
    SNOWFLAKE.CORTEX.TRANSLATE({{ text_col }}, {{ lang_col }}, 'en')
{% endmacro %}

{# Classify ticket body into support categories. #}
{% macro cortex_classify(text_col) %}
    SNOWFLAKE.CORTEX.CLASSIFY_TEXT(
        {{ text_col }},
        ['Billing Issue', 'Technical Support', 'Product Inquiry',
         'Complaint', 'Feature Request', 'Account Issue', 'General Question']
    ):label::string
{% endmacro %}

{# Return sentiment score as a float. #}
{% macro cortex_sentiment(text_col) %}
    SNOWFLAKE.CORTEX.SENTIMENT({{ text_col }})
{% endmacro %}

{# Determine ticket priority via LLM. Trims and lowercases the response. #}
{% macro cortex_priority(text_col, model='mistral-7b') %}
    trim(lower(regexp_replace(
        SNOWFLAKE.CORTEX.COMPLETE(
            '{{ model }}',
            'Classify this support ticket priority as one of: critical, high, medium, low. '
            || 'Reply with only the priority word. Ticket: '
            || left({{ text_col }}, 500)
        )::string,
        '[^a-zA-Z]', ''
    )))
{% endmacro %}
```

In models, call the macro — not the raw function:
```sql
{{ cortex_classify('body_english') }} as ai_category
{{ cortex_sentiment('body_english') }} as sentiment_score
```

---

## Incremental Strategy for OpenFlow CDC

The Silver models use `merge` so re-processed records from OpenFlow upserts are handled correctly.

### Watermark pattern
```sql
{% if is_incremental() %}
where updated_at > (
    select coalesce(max(updated_at), '1900-01-01'::timestamp_ntz)
    from {{ this }}
)
{% endif %}
```

Use `updated_at` (not `created_at`) as the watermark — OpenFlow upserts update `updated_at` on modified rows. Using `created_at` would miss updates to existing tickets.

### When to use `--full-refresh`
- When a Silver model's logic changes (new Cortex function, new column)
- When the source schema changes
- Never in production without a rollback plan

---

## Sources YML: Always Define Freshness

```yaml
# models/sources/sources.yml
sources:
  - name: raw
    description: Raw customer support data loaded by OpenFlow from PostgresDB
    database: SUPPORT_INTEL_DB
    schema: RAW
    loaded_at_field: _OPENFLOW_LOADED_AT
    freshness:
      warn_after: {count: 1, period: hour}
      error_after: {count: 3, period: hour}
    tables:
      - name: CUSTOMER_SUPPORT_TICKETS_2
        description: Customer support tickets migrated from PostgresDB via OpenFlow
        columns:
          - name: ID
            description: Primary key from PostgresDB
            tests: [unique, not_null]
          - name: BODY
            description: Raw ticket body text
          - name: LANGUAGE
            description: Language code of the ticket (e.g. en, de, fr)
          - name: UPDATED_AT
            description: Last updated timestamp — used as incremental watermark
            tests: [not_null]
          - name: _OPENFLOW_LOADED_AT
            description: Timestamp when OpenFlow loaded this row into Snowflake
```

Check source freshness before every pipeline run:
```bash
dbt source freshness --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt
```

---

## Properties YML: Full Pattern per Layer

### Bronze (`models/bronze/properties.yml`)
```yaml
models:
  - name: bronze_tickets_extracted
    description: Type-casts and filters raw ticket data from the RAW source. No business logic.
    columns:
      - name: ticket_id
        description: Unique ticket identifier
        tests: [unique, not_null]
      - name: body
        description: Original ticket body. Rows with null or empty body are filtered out.
        tests: [not_null]
      - name: language
        description: IETF language code (e.g. en, de, fr). Defaults to 'en' if missing.
      - name: updated_at
        description: Last updated in source — used as incremental watermark in Silver
        tests: [not_null]
```

### Silver (`models/silver/properties.yml`)
```yaml
models:
  - name: stg_tickets_translated
    description: Translates non-English subject and body to English using Cortex TRANSLATE.
    columns:
      - name: ticket_id
        tests: [unique, not_null]
      - name: body_english
        description: Body in English. Identical to body when language is already 'en'.

  - name: stg_tickets_classified
    description: Adds AI category using Cortex CLASSIFY_TEXT on the English body.
    columns:
      - name: ticket_id
        tests: [unique, not_null]
      - name: ai_category
        description: AI-classified support category
        tests:
          - not_null
          - accepted_values:
              values:
                - Billing Issue
                - Technical Support
                - Product Inquiry
                - Complaint
                - Feature Request
                - Account Issue
                - General Question

  - name: stg_tickets_sentiment
    description: Adds Cortex SENTIMENT score and a derived sentiment label.
    columns:
      - name: ticket_id
        tests: [unique, not_null]
      - name: sentiment_score
        description: Float from -1.0 (very negative) to 1.0 (very positive)
      - name: sentiment_label
        description: Bucketed label derived from sentiment_score
        tests:
          - accepted_values:
              values: [positive, neutral, negative]

  - name: silver_tickets_enriched
    description: Final Silver model. Adds LLM-based priority and assembles all enriched columns.
    config:
      materialized: incremental
      unique_key: ticket_id
      incremental_strategy: merge
      on_schema_change: append_new_columns
    columns:
      - name: ticket_id
        tests: [unique, not_null]
      - name: ai_priority
        description: LLM-determined priority — critical, high, medium, or low
        tests:
          - accepted_values:
              values: [critical, high, medium, low]
      - name: processed_at
        description: Timestamp when this row was enriched by the Silver pipeline
        tests: [not_null]
```

### Gold (`models/gold/properties.yml`)
```yaml
models:
  - name: mart_tickets_dashboard
    description: Analytics-ready mart for the Streamlit dashboard. Adds UI columns (priority_rank, sentiment_color) and sort order.
    config:
      materialized: table
    columns:
      - name: ticket_id
        tests: [unique, not_null]
      - name: priority_rank
        description: Numeric sort key — 1=critical, 2=high, 3=medium, 4=low, 5=unknown
      - name: sentiment_color
        description: UI display color — red=negative, green=positive, gray=neutral
```

---

## What `config()` Blocks Are Still Allowed In SQL

Only use an inline `{{ config() }}` in a SQL file when the model **deviates from the folder default** set in `dbt_project.yml`. Example: one Bronze model needs to be a `table` instead of a `view`:

```sql
-- bronze_customer_support_tickets.sql
-- This is the only Bronze model that needs to be a table (large, infrequently rebuilt)
{{ config(materialized='table') }}

select * from {{ source('raw', 'CUSTOMER_SUPPORT_TICKETS_2') }}
```

Otherwise, no `{{ config() }}` needed in the file at all.

---

## Testing Checklist

Run before every merge:
```bash
# Connection check
dbt debug --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt

# Source freshness
dbt source freshness --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt

# Schema tests only (fast)
dbt test --select test_type:generic --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt

# Full test suite
dbt test --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt
```

---

## Common Commands

```bash
# Full pipeline run
dbt run --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt

# Run one layer
dbt run --select bronze --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt
dbt run --select silver --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt
dbt run --select gold   --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt

# Run one model and everything downstream
dbt run --select stg_tickets_translated+ \
        --project-dir dbt/customer_support_dbt \
        --profiles-dir dbt/customer_support_dbt

# Full refresh a single Silver model
dbt run --select silver_tickets_enriched --full-refresh \
        --project-dir dbt/customer_support_dbt \
        --profiles-dir dbt/customer_support_dbt

# Generate and serve docs
dbt docs generate --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt
dbt docs serve    --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt --port 8085
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Key-pair auth failure | Check `~/.snowflake/rsa_key.p8` exists; public key must be set in Snowflake |
| Cortex function not found | Grant `SNOWFLAKE.CORTEX` privilege to `DBT_ROLE` |
| Incremental missing updated rows | Switch watermark from `created_at` to `updated_at` |
| `CLASSIFY_TEXT` returns NULL | Add `WHERE body_english IS NOT NULL AND TRIM(body_english) != ''` guard |
| `ai_priority` has unexpected values | The LLM sometimes returns prose — use `regexp_replace` + `trim(lower(...))` to clean |
| `accepted_values` test failing for `ai_category` | Check if `CLASSIFY_TEXT` label text matches the label list exactly (case-sensitive) |
