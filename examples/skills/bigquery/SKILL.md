---
name: bigquery
description: >
  Query tables, explore schemas, check data,
  run volume analysis, and validate entries
  using BigQuery
---

# BigQuery Skill

## When to Use
Use this skill when the user needs to:
- Query BigQuery tables for data analysis
- Explore table schemas and column details
- Run volume analysis or row counts
- Validate data entries across tables

## Instructions

### Environment
- Always use the **dev** project for queries unless the user explicitly says "prod"
- Dev project: `acme-dev.analytics_dev`
- Prod project: `acme-prod.analytics_prod`

### Cost Labels
Every query MUST include cost labels:
```sql
SET @@query_label = CONCAT("team:", "analytics");
SET @@query_label = CONCAT("costcenter:", "XXXXXX");
```

### Query Patterns

**Schema exploration:**
```sql
SELECT column_name, data_type, is_nullable
FROM `acme-dev.analytics_dev.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'target_table'
ORDER BY ordinal_position;
```

**Volume analysis:**
```sql
SELECT COUNT(*) as row_count,
       COUNT(DISTINCT primary_key) as unique_keys,
       MIN(created_date) as earliest,
       MAX(created_date) as latest
FROM `acme-dev.analytics_dev.target_table`;
```

### Guardrails
- Never run DELETE or UPDATE queries
- Always add a LIMIT clause to SELECT queries during exploration (default: 100)
- For large result sets, summarize findings rather than displaying raw output
