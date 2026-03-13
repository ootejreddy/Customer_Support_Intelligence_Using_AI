# Customer Support Intelligence Using AI

## Overview
Data engineering pipeline that processes customer support tickets using AI for text denoising.

## Architecture
```
HuggingFace CSV → NiFi → Kafka → Snowflake (RAW) → dbt Bronze → dbt Silver (AI Denoising)
```

## Tech Stack
| Component | Technology | Purpose |
|-----------|------------|---------|
| Data Warehouse | Snowflake | Central storage & AI |
| Transformations | dbt (dbt-snowflake) | Data modeling |
| Orchestration | Apache Airflow 2.8.2 | Workflow scheduling |
| Data Ingestion | Apache NiFi 1.25.0 | Data flow management |
| Streaming | Apache Kafka 7.8.0 | Real-time messaging |
| Stream Processing | Kafka Connect + Snowflake Connector | Stream to Snowflake |
| AI/ML | Snowflake Cortex (mistral-large2) | Ticket text denoising |

## Snowflake Configuration
- **Account**: gsvvwno-ts70298
- **Database**: SUPPORT_INTEL_DB
- **Schemas**: RAW, BRONZE, SILVER
- **Warehouse**: SUPPORT_DEV_WH
- **Roles**: DBT_ROLE, KAFKA_CONNECTOR_ROLE
- **Auth**: Key-pair authentication

## Directory Structure
```
├── dbt/customer_support_dbt/    # dbt project
│   ├── models/
│   │   ├── bronze/              # Raw data layer
│   │   ├── silver/              # Cleaned/denoised data
│   │   └── sources/             # Source definitions
│   └── profiles.yml             # Snowflake connection config
├── dags/                        # Airflow DAGs
├── nifi/data/huggingface/       # Source CSV data
├── kafka-connect/               # Kafka Connect plugins
└── docker-compose.yml           # Infrastructure stack
```

## Commands

### dbt
```bash
# Navigate to dbt project
cd dbt/customer_support_dbt

# Test connection
dbt debug --profiles-dir .

# Compile models
dbt compile --profiles-dir .

# Run models
dbt run --profiles-dir .

# Test models
dbt test --profiles-dir .
```

### Docker Services
```bash
# Start all services
docker compose up -d

# Start specific service
docker compose up -d kafka-connect

# View logs
docker logs kafka-connect --tail 50
```

### Kafka Connect
```bash
# List connectors
curl http://localhost:8083/connectors

# Check connector status
curl http://localhost:8083/connectors/snowflake_kafka_connector/status

# Deploy connector
curl -X POST http://localhost:8083/connectors -H "Content-Type: application/json" -d @snowflake-kafka-connector.json
```

## Key Files
| File | Purpose |
|------|---------|
| `docker-compose.yml` | Full infrastructure stack |
| `dbt/customer_support_dbt/profiles.yml` | dbt Snowflake connection (key-pair auth) |
| `dbt/customer_support_dbt/dbt_project.yml` | dbt project config |
| `snowflake-kafka-connector.json` | Kafka→Snowflake connector config |
| `.env` | Environment variables and secrets |

## Authentication
- **dbt**: Key-pair auth via `/Users/saiootejreddy/.snowflake/rsa_key.p8`
- **Kafka Connector**: Key-pair auth for KAFKA_CONNECTOR_USER (key in .env)

## Service Ports
| Service | Port |
|---------|------|
| Airflow | 8080 |
| NiFi | 8443 |
| Kafka | 9092, 29092 |
| Kafka Connect | 8083 |
| Conduktor Console | 8081 |
| Zookeeper | 2181 |
