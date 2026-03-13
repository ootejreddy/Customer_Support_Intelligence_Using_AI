# Enterprise dbt Workflow

## Overview
Comprehensive dbt workflow for Customer Support Intelligence project with production-grade practices.

## Project Configuration
- **Project Path**: `dbt/customer_support_dbt`
- **Profiles Path**: `dbt/customer_support_dbt/profiles.yml`
- **Target**: `dev`
- **Database**: `SUPPORT_INTEL_DB`
- **Schemas**: BRONZE, SILVER

## Workflows

### 1. Connection Validation
Before any dbt operation, validate the Snowflake connection:
```bash
dbt debug --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt
```

### 2. Full Build Pipeline
Execute complete build with dependencies:
```bash
dbt deps --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt
dbt seed --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt
dbt run --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt
dbt test --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt
```

### 3. Incremental Development
For iterative development on specific models:
```bash
# Compile single model
dbt compile --select <model_name> --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt

# Run single model with upstream dependencies
dbt run --select +<model_name> --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt

# Run single model with downstream dependencies
dbt run --select <model_name>+ --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt
```

### 4. Testing Strategy

#### Schema Tests
```bash
dbt test --select test_type:schema --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt
```

#### Data Tests
```bash
dbt test --select test_type:data --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt
```

#### Test Specific Model
```bash
dbt test --select <model_name> --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt
```

### 5. Documentation
```bash
# Generate docs
dbt docs generate --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt

# Serve docs locally
dbt docs serve --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt --port 8085
```

### 6. Freshness Checks
```bash
dbt source freshness --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt
```

## Model Layers

### Bronze Layer (Raw)
- **Schema**: BRONZE
- **Purpose**: Direct copy from RAW source
- **Materialization**: View or Table
- **Models**: `bronze_customer_support_tickets`

### Silver Layer (Staged/Cleaned)
- **Schema**: SILVER
- **Purpose**: Cleaned, denoised, business-ready data
- **Materialization**: Table (for AI processing)
- **Models**: 
  - `stg_customer_support_tickets` - Product name substitution
  - `stg_denoised_tickets` - AI-powered text denoising via Cortex

## Layer-Specific Commands

### Run Bronze Only
```bash
dbt run --select bronze --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt
```

### Run Silver Only
```bash
dbt run --select silver --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt
```

### Run Full Pipeline (Bronze → Silver)
```bash
dbt run --select bronze+ --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt
```

## CI/CD Commands

### Pre-commit Checks
```bash
dbt compile --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt
dbt test --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt --warn-error
```

### Production Deployment
```bash
dbt run --target prod --full-refresh --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt
dbt test --target prod --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt
```

### Rollback (Re-run from clean state)
```bash
dbt run --full-refresh --select <model_name> --project-dir dbt/customer_support_dbt --profiles-dir dbt/customer_support_dbt
```

## Troubleshooting

### Connection Issues
1. Verify key-pair authentication: Check `/Users/saiootejreddy/.snowflake/rsa_key.p8` exists
2. Validate public key is assigned to user in Snowflake
3. Run `dbt debug` to diagnose

### Model Failures
1. Check compiled SQL: `dbt/customer_support_dbt/target/compiled/`
2. Review run logs: `dbt/customer_support_dbt/logs/`
3. Test in Snowflake directly using compiled SQL

### Performance Issues
1. Check warehouse size: `SUPPORT_DEV_WH`
2. Review query profile in Snowflake
3. Consider incremental materialization for large tables

## Best Practices

### Naming Conventions
- Bronze: `bronze_<source>_<table>`
- Silver: `stg_<domain>_<entity>`
- Gold: `dim_<entity>`, `fact_<event>`, `agg_<metric>`

### Testing Requirements
- All models must have `unique` and `not_null` tests on primary keys
- Silver layer models should have data quality tests
- Source freshness configured for all sources

### Documentation
- All models must have descriptions in schema.yml
- Column descriptions required for business-critical fields
- Update docs after any schema changes

## Macros

### Custom Macros Location
`dbt/customer_support_dbt/macros/`

### Common Macro Patterns
- `generate_schema_name`: Custom schema naming
- `test_*`: Custom data tests
- `transform_*`: Reusable transformations

## Environment Variables
- Snowflake auth uses key-pair (no password env var needed for dbt)
- For CI/CD, set `DBT_PROFILES_DIR` to profiles location
