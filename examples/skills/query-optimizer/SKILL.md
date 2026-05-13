---
name: query-optimizer
description: >
  Analyze and optimize slow BigQuery queries — suggest partitioning,
  clustering, materialized views, and cost reduction strategies
---
# Query Optimizer

When the user asks to optimize, speed up, or reduce cost of a query:

1. **Identify anti-patterns:**
   - `SELECT *` instead of specific columns
   - Missing partition filters (scans entire table)
   - Cross joins or implicit cartesian products
   - Repeated subqueries that should be CTEs
   - Functions on partition columns that prevent pruning

2. **Suggest structural improvements:**
   - Add partition filter (`WHERE partition_date >= ...`)
   - Use clustering columns in WHERE/ORDER BY
   - Replace subqueries with CTEs or temp tables
   - Use approximate functions (`APPROX_COUNT_DISTINCT` vs `COUNT(DISTINCT)`)

3. **Estimate impact:**
   - "This change reduces scanned data from ~X TB to ~Y GB"
   - "Clustering on these columns improves filter performance by ~10x"

4. **Always check cost labels:**
   - Verify the query includes `SET @@query_label` statements
   - If missing, add them per team standards
