---
name: airflow-skill
description: Airflow DAG authoring with Astronomer Cosmos for dbt, Snowflake native Airflow integration, pipeline orchestration, debugging, and scheduling
---

# Airflow Skill — DAG Orchestration with Cosmos + Snowflake

## Overview

This skill handles all Airflow orchestration for the **Customer Support Intelligence** project. It covers authoring DAGs that orchestrate the full pipeline (OpenFlow trigger → dbt Bronze → Silver → Gold), using **Astronomer Cosmos** for native dbt-in-Airflow execution, and leveraging **Snowflake's native Airflow support** (available via Snowflake Open Catalog / Snowpark Container Services).

## Project Context

| Setting | Value |
|---------|-------|
| DAGs path | `dags/` |
| dbt project | `dbt/customer_support_dbt` |
| Snowflake database | `SUPPORT_INTEL_DB` |
| Snowflake warehouse | `SUPPORT_DEV_WH` |
| Pipeline trigger | After OpenFlow loads new data to RAW |
| Cosmos package | `astronomer-cosmos` |

## When to Use

Invoke this skill when the user asks to:
- Create or modify Airflow DAGs for the pipeline
- Integrate dbt runs via Astronomer Cosmos
- Set up Snowflake connections in Airflow
- Debug DAG failures or task retries
- Configure schedules, SLAs, or alerts
- Use cross-skill composition with `$dbt-skill` for dbt task details

## Pipeline DAG Design

```
openflow_check_sensor
        │
        ▼
dbt_bronze_run           (bronze_tickets_extracted)
        │
        ▼
dbt_silver_run           (silver_tickets_enriched — incremental)
        │
        ▼
dbt_gold_run             (mart_tickets_dashboard)
        │
        ▼
dbt_test_all
        │
        ▼
notify_success
```

## Core DAG — Full Pipeline

```python
# dags/customer_support_pipeline.py
from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.snowflake.operators.snowflake import SnowflakeOperator
from cosmos import DbtTaskGroup, ProjectConfig, ProfileConfig, ExecutionConfig
from cosmos.profiles import SnowflakePrivateKeyPathProfileMapping

# --- Cosmos / dbt config ---
profile_config = ProfileConfig(
    profile_name="customer_support_dbt",
    target_name="dev",
    profile_mapping=SnowflakePrivateKeyPathProfileMapping(
        conn_id="snowflake_default",
        profile_args={
            "database":  "SUPPORT_INTEL_DB",
            "warehouse": "SUPPORT_DEV_WH",
            "schema":    "DBT_SCHEMA",
        },
    ),
)

project_config = ProjectConfig(
    dbt_project_path="/opt/airflow/dbt/customer_support_dbt",
)

execution_config = ExecutionConfig(
    dbt_executable_path="/opt/airflow/.venv/bin/dbt",
)

# --- DAG definition ---
default_args = {
    "owner":            "data-engineering",
    "retries":          2,
    "retry_delay":      timedelta(minutes=5),
    "email_on_failure": True,
}

with DAG(
    dag_id="customer_support_pipeline",
    default_args=default_args,
    description="End-to-end pipeline: OpenFlow → dbt Bronze/Silver/Gold",
    schedule_interval="0 * * * *",          # hourly
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=["customer-support", "dbt", "snowflake"],
) as dag:

    # Check RAW table has new data since last run
    check_new_data = SnowflakeOperator(
        task_id="check_new_raw_data",
        snowflake_conn_id="snowflake_default",
        sql="""
            SELECT COUNT(*) AS new_rows
            FROM SUPPORT_INTEL_DB.RAW.CUSTOMER_SUPPORT_TICKETS_2
            WHERE _OPENFLOW_LOADED_AT >= DATEADD('hour', -1, CURRENT_TIMESTAMP());
        """,
    )

    # dbt Bronze → Silver → Gold via Cosmos
    dbt_pipeline = DbtTaskGroup(
        group_id="dbt_medallion_pipeline",
        project_config=project_config,
        profile_config=profile_config,
        execution_config=execution_config,
        operator_args={"install_deps": True},
    )

    # Post-run validation
    validate_gold = SnowflakeOperator(
        task_id="validate_gold_layer",
        snowflake_conn_id="snowflake_default",
        sql="""
            SELECT
                COUNT(*)                                AS total_tickets,
                SUM(CASE WHEN ai_priority = 'critical' THEN 1 ELSE 0 END) AS critical_count,
                SUM(CASE WHEN sentiment_label = 'Negative' THEN 1 ELSE 0 END) AS negative_count
            FROM SUPPORT_INTEL_DB.GOLD.MART_TICKETS_DASHBOARD;
        """,
    )

    check_new_data >> dbt_pipeline >> validate_gold
```

## Incremental-Only DAG (Lightweight, Frequent)

```python
# dags/customer_support_incremental.py
from datetime import datetime, timedelta
from airflow import DAG
from cosmos import DbtTaskGroup, ProjectConfig, ProfileConfig, ExecutionConfig
from cosmos.profiles import SnowflakePrivateKeyPathProfileMapping

with DAG(
    dag_id="customer_support_incremental",
    description="Incremental Silver layer refresh every 15 min",
    schedule_interval="*/15 * * * *",
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=["customer-support", "incremental"],
) as dag:

    dbt_incremental = DbtTaskGroup(
        group_id="dbt_incremental",
        project_config=project_config,
        profile_config=profile_config,
        execution_config=execution_config,
        select=["silver_tickets_enriched", "mart_tickets_dashboard"],
    )
```

## Snowflake Connection Setup

```python
# airflow/connections — set via UI or CLI
# Connection ID: snowflake_default
# Type: Snowflake
# Host: <account>.snowflakecomputing.com
# Schema: DBT_SCHEMA
# Login: <username>
# Extra:
{
  "account":    "<org>-<account>",
  "warehouse":  "SUPPORT_DEV_WH",
  "database":   "SUPPORT_INTEL_DB",
  "role":       "DBT_ROLE",
  "private_key_path": "/opt/airflow/.snowflake/rsa_key.p8"
}
```

```bash
# Or via CLI
airflow connections add snowflake_default \
  --conn-type snowflake \
  --conn-host "<account>.snowflakecomputing.com" \
  --conn-login "<username>" \
  --conn-extra '{"account":"<org>-<account>","warehouse":"SUPPORT_DEV_WH","database":"SUPPORT_INTEL_DB","role":"DBT_ROLE","private_key_path":"/opt/airflow/.snowflake/rsa_key.p8"}'
```

## Requirements

```txt
# requirements.txt additions
astronomer-cosmos[dbt-snowflake]>=1.5.0
apache-airflow-providers-snowflake>=5.0.0
apache-airflow>=2.8.0
```

## Cosmos Cross-Skill Note

When a user requests dbt model changes alongside DAG changes, this agent also invokes `$dbt-skill` to handle the model layer — keeping DAG logic and dbt SQL in sync.

## Debugging

```bash
# Test a DAG locally
airflow dags test customer_support_pipeline 2025-01-01

# Run a single task
airflow tasks test customer_support_pipeline check_new_raw_data 2025-01-01

# List DAGs
airflow dags list

# Trigger manually
airflow dags trigger customer_support_pipeline
```

### Common Issues

| Issue | Fix |
|-------|-----|
| Snowflake connection timeout | Increase `connection_timeout` in conn extra JSON |
| Cosmos can't find dbt | Set `dbt_executable_path` in `ExecutionConfig` |
| dbt task fails in Airflow but passes locally | Check env vars; ensure `profiles.yml` is accessible |
| Tasks run sequentially (slow) | Enable Airflow parallelism; use `CeleryExecutor` |
| Silver layer skipped | Check `check_new_raw_data` SQL returns > 0 rows |

## Best Practices

- Use `DbtTaskGroup` (Cosmos) over raw `BashOperator` for dbt — gives per-model task visibility
- Keep DAG files thin — DAG logic only; SQL lives in dbt models
- Use `schedule_interval="0 * * * *"` for hourly full runs; `*/15` for incremental Silver
- Always add a post-run `SnowflakeOperator` validation task
- Tag DAGs: `["customer-support", "dbt", "snowflake"]` for easy filtering in Airflow UI
