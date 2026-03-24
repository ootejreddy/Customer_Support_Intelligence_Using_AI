---
name: streamlit-skill
description: Streamlit in Snowflake (SiS) app development, Snowpark data access, caching, and deployment for the Customer Support Intelligence dashboard
---

# Streamlit Skill — Streamlit in Snowflake (SiS) Dashboard

## Overview

This skill covers building and deploying the **Customer Support Intelligence** dashboard as a **Streamlit in Snowflake (SiS)** application. SiS runs natively inside Snowflake — no external hosting, no secrets management — using **Snowpark** for data access and Streamlit for the UI.

## Project Context

| Setting | Value |
|---------|-------|
| App path | `streamlit_app/app.py` |
| Data source | `SUPPORT_INTEL_DB.GOLD.MART_TICKETS_DASHBOARD` |
| Deploy target | Snowflake SiS (Streamlit in Snowflake) |
| Snowpark session | Injected by SiS runtime |
| Database | `SUPPORT_INTEL_DB` |
| Warehouse | `SUPPORT_DEV_WH` |

## When to Use

Invoke this skill when the user asks to:
- Create or modify the Streamlit dashboard
- Switch from local Streamlit to Streamlit in Snowflake (SiS)
- Use Snowpark to query Gold layer data
- Add charts, KPIs, or filters
- Optimize query caching with `@st.cache_data`
- Deploy or update the SiS app
- Debug SiS-specific issues

## SiS App Architecture

```
GOLD.MART_TICKETS_DASHBOARD
        │  (Snowpark query)
        ▼
Streamlit in Snowflake App
        ├── KPI Metrics Row
        ├── Interactive Filters (sidebar)
        ├── Charts (Priority / Sentiment / Category)
        └── Ticket Explorer Table
```

## Core App — `streamlit_app/app.py`

```python
# streamlit_app/app.py
# Compatible with both local Streamlit and Streamlit in Snowflake (SiS)

import streamlit as st
import pandas as pd
from snowflake.snowpark.context import get_active_session
from snowflake.snowpark.functions import col

# ── Page config ────────────────────────────────────────────────────────────────
st.set_page_config(
    page_title="Customer Support Intelligence",
    page_icon="🎫",
    layout="wide",
)

# ── Snowpark session (SiS injects this automatically) ─────────────────────────
session = get_active_session()

# ── Cached data loader ─────────────────────────────────────────────────────────
@st.cache_data(ttl=300)   # refresh every 5 minutes
def load_tickets() -> pd.DataFrame:
    return (
        session.table("SUPPORT_INTEL_DB.GOLD.MART_TICKETS_DASHBOARD")
        .to_pandas()
    )

df = load_tickets()

# ── Sidebar filters ────────────────────────────────────────────────────────────
st.sidebar.title("Filters")

priorities  = ["All"] + sorted(df["AI_PRIORITY"].dropna().unique().tolist())
sentiments  = ["All"] + sorted(df["SENTIMENT_LABEL"].dropna().unique().tolist())
categories  = ["All"] + sorted(df["AI_CATEGORY"].dropna().unique().tolist())

sel_priority  = st.sidebar.selectbox("Priority",  priorities)
sel_sentiment = st.sidebar.selectbox("Sentiment", sentiments)
sel_category  = st.sidebar.selectbox("Category",  categories)

filtered = df.copy()
if sel_priority  != "All": filtered = filtered[filtered["AI_PRIORITY"]    == sel_priority]
if sel_sentiment != "All": filtered = filtered[filtered["SENTIMENT_LABEL"] == sel_sentiment]
if sel_category  != "All": filtered = filtered[filtered["AI_CATEGORY"]     == sel_category]

# ── KPI row ────────────────────────────────────────────────────────────────────
st.title("🎫 Customer Support Intelligence")
st.markdown("---")

c1, c2, c3, c4 = st.columns(4)
c1.metric("Total Tickets",    len(filtered))
c2.metric("Critical",         len(filtered[filtered["AI_PRIORITY"]    == "critical"]))
c3.metric("Negative Sentiment", len(filtered[filtered["SENTIMENT_LABEL"] == "Negative"]))
c4.metric("Positive Sentiment", len(filtered[filtered["SENTIMENT_LABEL"] == "Positive"]))

st.markdown("---")

# ── Charts ─────────────────────────────────────────────────────────────────────
col1, col2, col3 = st.columns(3)

with col1:
    st.subheader("Priority Distribution")
    priority_counts = filtered["AI_PRIORITY"].value_counts().reset_index()
    priority_counts.columns = ["Priority", "Count"]
    st.bar_chart(priority_counts.set_index("Priority"))

with col2:
    st.subheader("Sentiment Breakdown")
    sentiment_counts = filtered["SENTIMENT_LABEL"].value_counts().reset_index()
    sentiment_counts.columns = ["Sentiment", "Count"]
    st.bar_chart(sentiment_counts.set_index("Sentiment"))

with col3:
    st.subheader("Category Analysis")
    cat_counts = filtered["AI_CATEGORY"].value_counts().reset_index()
    cat_counts.columns = ["Category", "Count"]
    st.bar_chart(cat_counts.set_index("Category"))

# ── Ticket Explorer ────────────────────────────────────────────────────────────
st.markdown("---")
st.subheader("Ticket Explorer")

search = st.text_input("Search tickets (subject / body)")
if search:
    mask = (
        filtered["SUBJECT_ENGLISH"].str.contains(search, case=False, na=False) |
        filtered["BODY_ENGLISH"].str.contains(search, case=False, na=False)
    )
    filtered = filtered[mask]

display_cols = [
    "TICKET_ID", "SUBJECT_ENGLISH", "AI_CATEGORY",
    "SENTIMENT_LABEL", "AI_PRIORITY", "CREATED_AT"
]
st.dataframe(filtered[display_cols], use_container_width=True, height=400)
st.caption(f"Showing {len(filtered):,} tickets")
```

## Deploying to Streamlit in Snowflake

### Option 1 — Snowsight UI
1. Snowsight → **Streamlit** → **+ Streamlit App**
2. Name: `CUSTOMER_SUPPORT_DASHBOARD`
3. Warehouse: `SUPPORT_DEV_WH`
4. Database: `SUPPORT_INTEL_DB` / Schema: `GOLD`
5. Paste app code or upload `streamlit_app/app.py`

### Option 2 — SQL Deploy
```sql
CREATE OR REPLACE STREAMLIT SUPPORT_INTEL_DB.GOLD.CUSTOMER_SUPPORT_DASHBOARD
    ROOT_LOCATION = '@SUPPORT_INTEL_DB.GOLD.STREAMLIT_STAGE'
    MAIN_FILE = 'app.py'
    QUERY_WAREHOUSE = 'SUPPORT_DEV_WH'
    TITLE = 'Customer Support Intelligence';
```

```bash
# Upload app file to stage
snowsql -q "PUT file://streamlit_app/app.py @SUPPORT_INTEL_DB.GOLD.STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE"
```

### Option 3 — Snowflake CLI (snowcli)
```bash
snow streamlit deploy \
  --name CUSTOMER_SUPPORT_DASHBOARD \
  --file streamlit_app/app.py \
  --database SUPPORT_INTEL_DB \
  --schema GOLD \
  --warehouse SUPPORT_DEV_WH
```

## Local Development

```bash
# Install dependencies
pip install streamlit snowflake-snowpark-python pandas

# Run locally (uses secrets.toml for auth)
cd streamlit_app
streamlit run app.py
```

```toml
# streamlit_app/.streamlit/secrets.toml
[snowflake]
account   = "<org>-<account>"
user      = "<username>"
role      = "DBT_ROLE"
warehouse = "SUPPORT_DEV_WH"
database  = "SUPPORT_INTEL_DB"
schema    = "GOLD"
private_key_path = "~/.snowflake/rsa_key.p8"
```

## Caching Strategy

| Data | TTL | Notes |
|------|-----|-------|
| `load_tickets()` | 300s | Main Gold table; refreshes every 5 min |
| Aggregation counts | Derived from cached df | No extra query needed |
| Search filter | No cache | Real-time UI filter on cached df |

## Snowpark Patterns

```python
# Aggregate in Snowpark (pushdown — faster than pandas)
@st.cache_data(ttl=300)
def load_priority_summary():
    return (
        session.table("SUPPORT_INTEL_DB.GOLD.MART_TICKETS_DASHBOARD")
        .group_by("AI_PRIORITY")
        .count()
        .to_pandas()
    )

# Filter in Snowpark for large tables
@st.cache_data(ttl=300)
def load_critical_tickets():
    return (
        session.table("SUPPORT_INTEL_DB.GOLD.MART_TICKETS_DASHBOARD")
        .filter(col("AI_PRIORITY") == "critical")
        .select("TICKET_ID", "SUBJECT_ENGLISH", "SENTIMENT_LABEL", "CREATED_AT")
        .to_pandas()
    )
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `get_active_session()` fails locally | Use `snowflake.connector` + manual session for local dev |
| SiS app shows no data | Check GRANT SELECT on `MART_TICKETS_DASHBOARD` to app role |
| App too slow | Add `@st.cache_data(ttl=300)` to all data loaders |
| Column names lowercase in pandas | Snowflake returns UPPERCASE; use `df["COLUMN_NAME"]` |
| SiS deploy fails | Check `ROOT_LOCATION` stage exists and file is uploaded |

## Best Practices

- Use `get_active_session()` — it works in both SiS and local (with Snowpark connection)
- Always `@st.cache_data(ttl=300)` on data loaders — SiS re-runs on every interaction
- Keep heavy aggregations in dbt Gold models, not in Streamlit
- Use Snowpark `.filter()` and `.select()` before `.to_pandas()` to minimize data transfer
- Column names from Snowflake are UPPERCASE — be consistent in your code
