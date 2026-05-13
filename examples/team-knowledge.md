# Team Knowledge Base (Shared)

## 1. Team Standards

### Environment Config
| Environment | Project | Dataset |
|---|---|---|
| Dev | acme-dev | analytics_dev |
| Test | acme-test | analytics_test |
| Prod | acme-prod | analytics_prod |

Never use `acme-compute-dev` — that's the Compute project, not Storage.

### Cost Labels (Required on ALL queries)
```sql
SET @@query_label = CONCAT("team:", "{{team}}");
SET @@query_label = CONCAT("costcenter:", "{{costcenter}}");
SET @@query_label = CONCAT("project:", "{{project}}");
```

### Git Workflow
- Branch naming: ticket-prefix-description (flat hyphens, no slashes)
- PR target: always `develop`, never `main`
- `main` is PROD — always check `origin/main` for current prod state
- `develop` is for dev/test only — may contain unreleased changes

### Style Conventions
- Do NOT add header comment blocks
- Preserve original inline comments as-is
- Match existing prod query formatting


# Dependency Map

## 1. Service Registry
| Repo | Domain | Purpose | Key Workflows |
|---|---|---|---|
| data-intake | ingestion | Raw data intake from external feeds | WF-10, WF-11 |
| data-transform | batch | Daily/weekly data preparation | WF-20, WF-21, WF-22 |
| feature-engine | batch | Feature computation and scoring | WF-30, WF-31 |
| data-export | delivery | Downstream delivery and reporting | WF-40, WF-41 |
| event-processor | streaming | Real-time event processing | — (streaming) |
| analytics-agent | agents | AI-powered data analysis | — (API) |

## 2. Workflow Dependency Graph
| Upstream | Upstream Service | → | Downstream | Downstream Service | Timing |
|---|---|---|---|---|---|
| WF-10 (ingest) | data-intake | → | WF-20 (transform) | data-transform | 30 min delta |
| WF-20 (transform) | data-transform | → | WF-30 (features) | feature-engine | Schedule align |
| WF-30 (features) | feature-engine | → | WF-40 (export) | data-export | 60 min delta |

## 3. Data Lineage Index
| Table | Producing Service | Consuming Services |
|---|---|---|
| raw_events | data-intake | data-transform |
| core_records | data-transform | feature-engine, data-export |
| enriched_features | feature-engine | data-export, analytics-agent |
| export_staging | data-export | (external consumers) |

## 4. Quick Reference
| Working On | Primary Repo | Also Check |
|---|---|---|
| New data source | data-intake | data-transform (schema impact) |
| New feature | feature-engine | data-export (downstream impact) |
| Schema change | data-transform | ALL downstream services |
| WF-20 failure | data-transform | Everything downstream |


## On-Demand References
Load these with the Read tool when a task needs them.

- **Batch Processing Standards** — Read `cache/wiki/domain_batch.md`
  Load when: working on batch workflows or data transformation
- **Streaming Standards** — Read `cache/wiki/domain_streaming.md`
  Load when: working on real-time pipelines
- **Service: data-intake** — Read `cache/wiki/data-intake.md`
  Load when: working in data-intake repo

## Recent Learnings (Auto-Updated)

### 2026-05-10: CLI Query Labels Need --label Flags
- **Problem:** `SET @@query_label` only works in session mode. CLI queries ignore SET statements silently.
- **Solution:** Use `--label` flags with CLI commands: `bq query --label team:analytics --label costcenter:123456`

### 2026-05-08: Contact Lookup Strategy
- **Problem:** Searching contacts by page title misses most results — contact pages have generic titles.
- **Solution:** Search by content (`text ~`), not title. Always clarify the type of contact before searching.
