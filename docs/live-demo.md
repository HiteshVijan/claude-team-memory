# Live Demo: Context Memory with a Real Wiki

This guide walks you through setting up a live demo using a Confluence Cloud wiki. The demo wiki at [vijan573.atlassian.net](https://vijan573.atlassian.net) shows exactly how Context Memory connects to a real wiki.

You can replicate this with any free Confluence Cloud, Notion, or GitBook instance.

---

## Demo Wiki Structure

Create these pages in your wiki to demonstrate the full 4-tier architecture:

### Page 1: Team Standards (Tier 1)

**Title:** `Team Standards`

```markdown
# Analytics Platform — Team Standards

## Environment Config
| Environment | Project | Dataset |
|---|---|---|
| Dev | acme-dev | analytics_dev |
| Prod | acme-prod | analytics_prod |

Never use `acme-compute-dev` — that's the Compute project, not Storage.

## Git Workflow
- PR target: always `develop`, never `main`
- Branch naming: TICKET-NUMBER-description (flat hyphens)
- `main` is PROD — always check `origin/main` for current prod state

## Cost Labels (required on ALL queries)
- team=analytics, costcenter=550100, project=analytics-platform

## Query Standards
- All CREATE TABLE must include OPTIONS block with expiration + labels
- All queries must start with cost label SET statements
- Use parameterized references: `{{target_schema}}`
```

### Page 2: Dependency Map (Tier 2)

**Title:** `Dependency Map`

```markdown
# Service Dependency Map

## Service Registry
| Repo | Domain | Purpose |
|---|---|---|
| data-intake | ingestion | Raw data intake from external feeds |
| data-transform | batch | Daily/weekly data preparation |
| feature-engine | batch | Feature computation and scoring |
| data-export | delivery | Downstream delivery and reporting |
| event-processor | streaming | Real-time event processing |

## Workflow Dependency Graph
| Upstream | → | Downstream | Timing |
|---|---|---|---|
| WF-10 (ingest) | → | WF-20 (transform) | 30 min delta |
| WF-20 (transform) | → | WF-30 (features) | Schedule align |
| WF-30 (features) | → | WF-40 (export) | 60 min delta |

## Data Lineage
| Table | Producer | Consumers |
|---|---|---|
| raw_events | data-intake | data-transform |
| core_records | data-transform | feature-engine, data-export |
| enriched_features | feature-engine | data-export, analytics-agent |

## Quick Reference
| Working On | Also Check |
|---|---|
| Schema change in data-transform | ALL downstream services |
| New rule in feature-engine | data-export (downstream impact) |
```

### Page 3: Module Detail (Tier 3) — one per repo

**Title:** `Module: feature-engine`

```markdown
# feature-engine — Module Detail

## Purpose
Feature computation and scoring engine. Produces `enriched_features`
consumed by data-export and analytics-agent.

## Workflow Chain
WF-30: pull_data → compute_features → score_records → write_output

## Key Files
| File | Purpose |
|---|---|
| queries/compute_features.sql | Main feature computation |
| queries/score_records.sql | Scoring rules applied to features |
| config/dag_config.py | Environment-specific config |

## Business Context
- Runs daily at 4:00 AM EST after WF-20 completes
- Feature scores feed into downstream alerting (data-export WF-40)
- Schema changes require coordinating with data-export team
```

### Page 4: Contacts & SOPs (Tier 4 — On-Demand)

**Title:** `Contacts & Escalation`

```markdown
# Team Contacts & Escalation Paths

## By Issue Type
| Issue | Primary Contact | Escalation |
|---|---|---|
| Pipeline failure (batch) | On-call DE | DE Team Lead |
| Infrastructure (compute) | Platform Team DL | Infrastructure Lead |
| Data quality | Data Quality DL | Analytics Lead |
| Deployment approval | Release Manager | Engineering Director |
| Security incident | Security DL | CISO Office |

## Distribution Lists
- DE Team: de-team@acme.com
- Platform: platform-eng@acme.com
- Incidents: incidents@acme.com

## SOP Index
| SOP | When to Use | Location |
|---|---|---|
| Pipeline Failure Runbook | Any batch workflow failure | wiki/runbooks/pipeline-failure |
| Deployment Checklist | Before any prod deployment | wiki/checklists/deployment |
| Incident Response | P1/P2 incidents | wiki/runbooks/incident-response |
| New Service Onboarding | Adding a new repo/service | wiki/guides/new-service |
```

---

## Demo Wiki Config

The demo pages are already set up on [vijan573.atlassian.net/wiki](https://vijan573.atlassian.net/wiki/spaces/SD/pages/491521/Context+Memory+Demo) in the SD space. Here's the config pointing to them:

```json
{
  "_meta": {
    "wiki_provider": "confluence",
    "wiki_base_url": "https://vijan573.atlassian.net",
    "space_key": "SD",
    "shared_page_id": "524289",
    "dependency_map_page_id": "557057"
  },
  "repos": {
    "feature-engine": {
      "page_id": "589825",
      "domain": "batch-processing"
    }
  }
}
```

| Page | Tier | Page ID | URL |
|------|------|---------|-----|
| Team Standards | 1 | 524289 | [Link](https://vijan573.atlassian.net/wiki/spaces/SD/pages/524289/Team+Standards) |
| Dependency Map | 2 | 557057 | [Link](https://vijan573.atlassian.net/wiki/spaces/SD/pages/557057/Dependency+Map) |
| Module: feature-engine | 3 | 589825 | [Link](https://vijan573.atlassian.net/wiki/spaces/SD/pages/589825/Module+feature-engine) |
| Contacts & Escalation | 4 | 524306 | [Link](https://vijan573.atlassian.net/wiki/spaces/SD/pages/524306/Contacts+and+Escalation) |

To replicate with your own wiki, replace the page IDs with yours.

## Running the Demo

### 1. Show the problem (without Context Memory)

Start a Claude Code session WITHOUT the hook installed:

```
You: What project ID should I use for dev queries?
Claude: I'm not sure — can you tell me your project configuration?

You: How about cost labels?
Claude: What cost labels does your team require?

You: If I change core_records schema, what breaks?
Claude: I don't have visibility into your service dependencies.
```

**3 questions, 0 useful answers.**

### 2. Install Context Memory

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HiteshVijan/claude-team-memory/main/scripts/quick-install.sh)
```

Configure wiki credentials, run `pull_knowledge.sh`.

### 3. Show the solution (with Context Memory)

Start a NEW Claude Code session:

```
You: What project ID should I use for dev queries?
Claude: Use acme-dev.analytics_dev. Never use acme-compute-dev —
        that's the Compute project, not Storage.

You: If I change core_records schema, what breaks?
Claude: core_records is consumed by feature-engine and data-export.
        A schema change here impacts both downstream services.
        WF-30 (features) depends on this table from WF-20.

You: Who do I contact about a pipeline failure?
Claude: *loads on-demand contacts page*
        Primary: On-call DE. Escalation: DE Team Lead.
        DL: de-team@acme.com
```

**3 questions, 3 instant answers. Zero re-explaining.**

### 4. Show the push (bidirectional)

```
You: FYI — I just found out that the bq CLI ignores SET @@query_label.
     You have to use --label flags instead.

Claude: LEARNING DETECTED — review before push

          Title:    CLI Query Labels Need --label Flags
          Date:     2026-05-12
          Category: standard
          Scope:    cross-team
          Target:   → Team Standards page

        Push? [approve / edit / skip]

You: approve

Claude: ✓ Pushed to wiki. Next session will auto-load this learning.
```

**Knowledge captured, structured, and shared — in 10 seconds.**

---

## Demo Talking Points

When presenting to stakeholders:

1. **"Every session starts from zero"** — show the before (3 unanswered questions)
2. **"560 lines of context, auto-loaded"** — show the after (instant answers)
3. **"Bidirectional"** — show the push (learning captured and shared)
4. **"It compounds"** — show the wiki page growing with learnings over time
5. **"Day 1 onboarding"** — "A new teammate installs this in 5 minutes and gets everything the team knows"
