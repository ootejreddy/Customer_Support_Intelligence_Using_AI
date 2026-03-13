# 🎫 Customer Support Intelligence Using AI

> An end-to-end data engineering pipeline that processes customer support tickets using **Snowflake Cortex AI** for intelligent text analysis, translation, categorization, sentiment analysis, and priority determination.

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)
![Apache Kafka](https://img.shields.io/badge/Apache%20Kafka-231F20?style=for-the-badge&logo=apachekafka&logoColor=white)
![dbt](https://img.shields.io/badge/dbt-FF694B?style=for-the-badge&logo=dbt&logoColor=white)
![Apache NiFi](https://img.shields.io/badge/Apache%20NiFi-017CEE?style=for-the-badge&logo=apache&logoColor=white)
![Streamlit](https://img.shields.io/badge/Streamlit-FF4B4B?style=for-the-badge&logo=streamlit&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Architecture](#-architecture)
- [Tech Stack](#-tech-stack)
- [Features](#-features)
- [Project Structure](#-project-structure)
- [Data Pipeline](#-data-pipeline)
- [AI Capabilities](#-ai-capabilities)
- [Getting Started](#-getting-started)
- [Usage](#-usage)
- [Dashboard](#-dashboard)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🎯 Overview

This project demonstrates a modern **Medallion Architecture** (Bronze → Silver → Gold) for processing customer support tickets at scale. It leverages **Snowflake Cortex AI functions** to automatically:

- 🌐 **Translate** tickets from any language to English
- 📂 **Categorize** tickets into predefined support categories
- 😊 **Analyze sentiment** to identify frustrated customers
- 🚨 **Determine priority** using AI-powered analysis

The pipeline ingests data from HuggingFace datasets through Apache NiFi, streams it via Kafka, and lands it in Snowflake for transformation and analysis.

---

## 🏗 Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           DATA PIPELINE ARCHITECTURE                             │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│   ┌────────────┐    ┌────────┐    ┌─────────┐    ┌────────────────────────┐     │
│   │ HuggingFace│───▶│  NiFi  │───▶│  Kafka  │───▶│  Snowflake Connector   │     │
│   │   Dataset  │    │        │    │         │    │  (Snowpipe Streaming)  │     │
│   └────────────┘    └────────┘    └─────────┘    └───────────┬────────────┘     │
│                                                              │                   │
│                                                              ▼                   │
│   ┌──────────────────────────────────────────────────────────────────────────┐  │
│   │                            SNOWFLAKE                                      │  │
│   │                                                                           │  │
│   │   ┌─────────┐      ┌─────────┐      ┌─────────┐      ┌─────────────┐     │  │
│   │   │   RAW   │─────▶│ BRONZE  │─────▶│ SILVER  │─────▶│    GOLD     │     │  │
│   │   │         │      │         │      │         │      │             │     │  │
│   │   │ Variant │      │ Extract │      │ AI/ML   │      │  Analytics  │     │  │
│   │   │  Data   │      │ Fields  │      │ Enrich  │      │    Ready    │     │  │
│   │   └─────────┘      └─────────┘      └─────────┘      └──────┬──────┘     │  │
│   │                                                              │            │  │
│   └──────────────────────────────────────────────────────────────────────────┘  │
│                                                              │                   │
│                                                              ▼                   │
│                                                     ┌────────────────┐           │
│                                                     │   Streamlit    │           │
│                                                     │   Dashboard    │           │
│                                                     └────────────────┘           │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🛠 Tech Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| 🏔️ **Data Warehouse** | Snowflake | Central storage & AI processing |
| 🔄 **Transformations** | dbt (dbt-snowflake) | Data modeling & testing |
| 🌊 **Data Ingestion** | Apache NiFi 1.25.0 | Data flow management |
| 📨 **Streaming** | Apache Kafka 7.8.0 | Real-time messaging |
| 🔌 **Stream Processing** | Kafka Connect + Snowflake Connector | Stream to Snowflake |
| 🤖 **AI/ML** | Snowflake Cortex | Translation, Classification, Sentiment |
| 📊 **Visualization** | Streamlit | Interactive dashboard |
| 🐳 **Infrastructure** | Docker Compose | Container orchestration |

---

## ✨ Features

### 🔄 Real-Time Data Ingestion
- Continuous streaming from Kafka to Snowflake
- Snowpipe Streaming for low-latency ingestion
- Automatic schema evolution support

### 🧠 AI-Powered Analysis
- **Multi-language support** - Automatic translation to English
- **Smart categorization** - 7 predefined support categories
- **Sentiment analysis** - Positive, Neutral, Negative classification
- **Priority scoring** - Critical, High, Medium, Low levels

### 📈 Analytics Dashboard
- Real-time KPI metrics
- Interactive filtering by priority, sentiment, category
- Visual charts and trend analysis
- Detailed ticket explorer

### 🏗️ Medallion Architecture
- **Bronze**: Raw data extraction with data quality checks
- **Silver**: AI enrichment and transformation
- **Gold**: Analytics-ready aggregations

---

## 📁 Project Structure

```
Customer_Support_Intelligence_Using_AI/
│
├── 📂 dbt/
│   └── customer_support_dbt/
│       ├── models/
│       │   ├── bronze/                    # 🥉 Raw data extraction
│       │   │   ├── bronze_tickets_extracted.sql
│       │   │   └── properties.yml
│       │   ├── silver/                    # 🥈 AI enrichment layer
│       │   │   ├── silver_tickets_enriched.sql
│       │   │   └── properties.yml
│       │   ├── gold/                      # 🥇 Analytics mart
│       │   │   ├── mart_tickets_dashboard.sql
│       │   │   └── properties.yml
│       │   └── sources/
│       │       └── sources.yml
│       ├── macros/
│       │   ├── generate_schema_name.sql
│       │   └── cortex_functions.sql
│       ├── dbt_project.yml
│       └── profiles.yml
│
├── 📂 streamlit_app/
│   ├── app.py                             # 📊 Dashboard application
│   └── .streamlit/
│       └── secrets.toml
│
├── 📂 dags/                               # 🔄 Airflow DAGs (future)
│
├── 📂 nifi/
│   └── data/
│       └── huggingface/                   # 📥 Source data
│
├── 📂 kafka-connect/
│   └── plugins/                           # 🔌 Snowflake connector
│
├── 📂 .cortex/
│   └── skills/                            # 🤖 Custom AI skills
│
├── 🐳 docker-compose.yml                  # Infrastructure stack
├── 📄 snowflake-kafka-connector.json      # Connector configuration
├── 📖 IMPLEMENTATION_GUIDE.md             # Detailed implementation docs
└── 📖 README.md                           # This file
```

---

## 🔄 Data Pipeline

### Stage 1: Data Ingestion 📥

```
HuggingFace Dataset → Apache NiFi → Kafka Topic
```

- Source: Customer support ticket dataset from HuggingFace
- NiFi processors handle data extraction and formatting
- Kafka topic: `CUSTOMER_SUPPORT_TICKETS`

### Stage 2: Stream to Snowflake 🌊

```
Kafka → Snowflake Kafka Connector → RAW.CUSTOMER_SUPPORT_TICKETS
```

- Snowpipe Streaming for real-time ingestion
- Data lands as VARIANT type (JSON)
- Automatic offset tracking

### Stage 3: Bronze Layer (Extraction) 🥉

```sql
-- Extract fields from Kafka VARIANT data
SELECT
    md5(partition || '-' || offset || '-' || topic) as ticket_id,
    parse_json(record_content):subject::string as subject,
    parse_json(record_content):body::string as body,
    parse_json(record_content):language::string as language,
    ...
FROM RAW.CUSTOMER_SUPPORT_TICKETS
```

### Stage 4: Silver Layer (AI Enrichment) 🥈

```sql
-- Translate non-English tickets
SNOWFLAKE.CORTEX.TRANSLATE(body, language, 'en') as body_english,

-- Categorize tickets
SNOWFLAKE.CORTEX.CLASSIFY_TEXT(body_english, 
    ['Billing Issue', 'Technical Support', 'Product Inquiry', 
     'Complaint', 'Feature Request', 'Account Issue', 'General Question']
) as ai_category,

-- Analyze sentiment
SNOWFLAKE.CORTEX.SENTIMENT(body_english) as sentiment_score,

-- Determine priority with LLM
SNOWFLAKE.CORTEX.COMPLETE('mistral-7b', priority_prompt) as ai_priority
```

### Stage 5: Gold Layer (Analytics) 🥇

```sql
-- Analytics-ready mart with derived columns
SELECT
    *,
    CASE ai_priority
        WHEN 'critical' THEN 1
        WHEN 'high' THEN 2
        WHEN 'medium' THEN 3
        ELSE 4
    END as priority_rank
FROM silver_tickets_enriched
```

---

## 🤖 AI Capabilities

### Snowflake Cortex Functions Used

| Function | Purpose | Example Output |
|----------|---------|----------------|
| `TRANSLATE` | Multi-language translation | "Hola" → "Hello" |
| `CLASSIFY_TEXT` | Category classification | "Technical Support" |
| `SENTIMENT` | Sentiment scoring | -0.75 (negative) |
| `COMPLETE` | LLM-based priority | "critical" |

### Category Classification

The system classifies tickets into these categories:

- 💰 **Billing Issue** - Payment and invoice problems
- 🔧 **Technical Support** - Technical difficulties
- ❓ **Product Inquiry** - Product questions
- 😤 **Complaint** - Customer complaints
- 💡 **Feature Request** - New feature suggestions
- 👤 **Account Issue** - Account-related problems
- 📋 **General Question** - Other inquiries

### Sentiment Analysis

| Score Range | Label | Color |
|-------------|-------|-------|
| ≥ 0.3 | Positive 😊 | 🟢 Green |
| -0.3 to 0.3 | Neutral 😐 | ⚪ Gray |
| ≤ -0.3 | Negative 😠 | 🔴 Red |

---

## 🚀 Getting Started

### Prerequisites

- 🐳 Docker & Docker Compose
- 🐍 Python 3.9+
- 🏔️ Snowflake Account with Cortex enabled
- 📦 dbt-snowflake

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/Customer_Support_Intelligence_Using_AI.git
cd Customer_Support_Intelligence_Using_AI
```

### 2. Start Infrastructure

```bash
# Start all services
docker compose up -d

# Verify services are running
docker ps
```

### 3. Configure Snowflake Connection

Create your Snowflake connection profile:

```yaml
# dbt/customer_support_dbt/profiles.yml
customer_support_dbt:
  outputs:
    dev:
      type: snowflake
      account: <your-account>
      user: <your-user>
      database: SUPPORT_INTEL_DB
      warehouse: SUPPORT_DEV_WH
      role: DBT_ROLE
      schema: DBT_SCHEMA
      # Use key-pair or password authentication
```

### 4. Run dbt Models

```bash
cd dbt/customer_support_dbt

# Test connection
dbt debug --profiles-dir .

# Run all models
dbt run --profiles-dir .

# Run tests
dbt test --profiles-dir .
```

### 5. Launch Dashboard

```bash
cd streamlit_app
streamlit run app.py
```

---

## 📖 Usage

### Running the Pipeline

```bash
# Run full pipeline (Bronze → Silver → Gold)
dbt run --select bronze_tickets_extracted+

# Run with full refresh
dbt run --select bronze_tickets_extracted+ --full-refresh

# Run specific layer
dbt run --select silver_tickets_enriched
```

### Checking Kafka Connector

```bash
# List connectors
curl http://localhost:8083/connectors

# Check status
curl http://localhost:8083/connectors/snowflake_kafka_connector/status
```

### Querying Results

```sql
-- View AI-enriched tickets
SELECT 
    subject_english,
    ai_category,
    sentiment_label,
    ai_priority
FROM SUPPORT_INTEL_DB.GOLD.MART_TICKETS_DASHBOARD
WHERE ai_priority = 'critical'
ORDER BY sentiment_score ASC;
```

---

## 📊 Dashboard

The Streamlit dashboard provides:

### 📈 KPI Metrics
- Total ticket count
- Critical priority tickets
- Negative sentiment tickets
- Positive sentiment tickets

### 🎛️ Interactive Filters
- Filter by AI Priority (Critical, High, Medium, Low)
- Filter by Sentiment (Positive, Neutral, Negative)
- Filter by Category (7 categories)

### 📉 Visualizations
- Priority distribution chart
- Sentiment breakdown
- Category analysis
- Time-based trends

### 📋 Ticket Explorer
- Searchable data table
- Full ticket details
- Export capabilities

---

## 🗂️ Database Schema

```
SUPPORT_INTEL_DB
├── 📁 RAW
│   └── CUSTOMER_SUPPORT_TICKETS    # Kafka ingested data
├── 📁 BRONZE
│   └── BRONZE_TICKETS_EXTRACTED    # Extracted fields
├── 📁 SILVER
│   └── SILVER_TICKETS_ENRICHED     # AI-enriched data
└── 📁 GOLD
    └── MART_TICKETS_DASHBOARD      # Analytics-ready
```

---

## 🔌 Service Ports

| Service | Port | URL |
|---------|------|-----|
| 🌊 Apache NiFi | 8443 | https://localhost:8443 |
| 📨 Kafka | 9092 | localhost:9092 |
| 🔌 Kafka Connect | 8083 | http://localhost:8083 |
| 📺 Conduktor Console | 8081 | http://localhost:8081 |
| 📊 Streamlit | 8501 | http://localhost:8501 |

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- [Snowflake](https://www.snowflake.com/) for Cortex AI capabilities
- [HuggingFace](https://huggingface.co/) for the customer support dataset
- [dbt Labs](https://www.getdbt.com/) for the transformation framework
- [Apache Foundation](https://apache.org/) for NiFi and Kafka

---

<p align="center">
  Made with ❤️ using Snowflake Cortex AI
</p>

<p align="center">
  <a href="#-customer-support-intelligence-using-ai">⬆️ Back to Top</a>
</p>
