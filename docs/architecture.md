# Architecture: 4-Tier Knowledge System

## Overview

Context Memory organizes team knowledge into four tiers based on scope and loading strategy. The goal: every Claude Code session has the right context without bloating the context window.

```
┌──────────────────────────────────────────────────────────────────┐
│                        Context Window                            │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │ Tier 1: Team Standards (always loaded, ~50 lines)        │    │
│  │  - Coding conventions, env config, branch rules          │    │
│  │  - Cost/billing labels, project IDs                      │    │
│  │  - Tool routing table (which tool for which question)    │    │
│  └──────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │ Tier 2: Dependency Map (always loaded, ~200 lines)       │    │
│  │  - Service registry (all repos with purpose & workflows) │    │
│  │  - Workflow dependency graph (upstream → downstream)     │    │
│  │  - Data lineage (producer → consumers)                   │    │
│  │  - "Working on X? Also check Y" quick reference          │    │
│  └──────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │ Tier 3: Module Detail (on-demand, ~100 lines per repo)   │    │
│  │  - Task chains for this repo                             │    │
│  │  - Query/script file listings                            │    │
│  │  - Business context and domain rules                     │    │
│  └──────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐   │
│    Tier 4: On-Demand References (loaded when task needs it)      │
│  │  - Domain-specific standards (agent dev, ML pipelines)   │   │
│    - Cross-service module pages (via cache or wiki API)          │
│  │  - Reference material (infra contacts, deploy runbooks)  │   │
│  └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘   │
└──────────────────────────────────────────────────────────────────┘
```

## Tier Breakdown

### Tier 1: Team Standards (~50 lines, always loaded)

The foundational guardrails that apply to every task in every repo.

**What goes here:**
- Environment project IDs (dev/test/prod)
- Cost and billing label requirements
- Git workflow rules (branch naming, PR targets, prod vs dev branches)
- Tool routing table (which external tool answers which question type)
- Skill routing pointer (auto-generated, loaded separately)

**Why always loaded:** These are the rules that prevent mistakes. A query without cost labels, a PR to the wrong branch, a reference to the wrong project ID — these errors burn hours. Loading 50 lines is cheap; fixing a wrong-environment query is not.

**Example:**
```markdown
## Environment Config
- Dev:  `mycompany-dev.team_dataset_dev`
- Prod: `mycompany-prod.team_dataset_prod`
- Never use `mycompany-infra-dev` — that's Compute, not Storage

## Git Workflow
- PR target: always `develop`, never `main`
- `main` is PROD — always check `origin/main` for current prod state
- Branch naming: ticket-prefix-description (flat hyphens, no slashes)

## Cost Labels (required on ALL queries)
- team=analytics, costcenter=XXXXXX, project=analytics-platform
```

### Tier 2: Dependency Map (~200 lines, always loaded)

The cross-service topology map. This is the "hub" that tells you how repos, workflows, and tables connect across your ecosystem.

**Three structured lookup tables:**

1. **Service Registry** — every repo with its domain, purpose, and key workflows
2. **Workflow Dependency Graph** — upstream → downstream relationships with timing
3. **Data Lineage Index** — every shared table with its producer and consumers

**Why always loaded:** Cross-service questions are the most common source of wrong answers. Without the dependency map, the AI doesn't know that changing a table schema in Service A breaks 4 downstream consumers in Services B, C, D, and E.

**Example:**
```markdown
## Workflow Dependency Graph
| Upstream          | Upstream Service | → | Downstream        | Downstream Service |
|---|---|---|---|---|
| ingest-workflow   | data-intake      | → | transform-daily   | data-transform     |
| transform-daily   | data-transform   | → | detect-weekly     | rule-engine        |

## Data Lineage Index
| Table              | Producing Service  | Consuming Services                     |
|---|---|---|
| core_records       | data-transform     | rule-engine, reporting, analytics      |
| enriched_features  | data-transform     | rule-engine, reporting                 |
```

### Tier 3: Module Detail (~100 lines per repo, on-demand)

Deep detail for the specific repo you're working in. Each repo has its own detail page on the wiki, cached locally.

**What goes here:**
- Full workflow task chains (task1 → task2 → task3 with descriptions)
- Query/script file listings with what each file does
- Repo-specific business context and domain rules
- Config variables and their values per environment

**Loading strategy:**
1. All repo detail pages are pre-cached at `~/.claude/cache/wiki/{repo-name}.md`
2. `team_knowledge.md` includes pointers (not full content) for each repo's cache file
3. Claude reads the cached file via Read tool when a task involves that repo
4. Wiki API is only called if the cache file is missing

**Currently supported:** Confluence (REST API v1 with body.storage expansion). The architecture is wiki-agnostic — Notion and GitBook adapters are planned (~20 lines to add).

### Tier 4: On-Demand References (loaded when needed)

Reference material that's too specialized to load by default but critical when relevant.

**What goes here:**
- Domain-specific standards (agent development, ML pipelines, frontend patterns)
- Infrastructure runbooks (deployment steps, prod support procedures)
- Contact directories and escalation paths
- Cross-team architecture documentation

**Loading strategy:** `team_knowledge.md` includes a "Load these when..." section that tells Claude which cache file to read for which task type.

**Example:**
```markdown
## On-Demand Detail Sections
- **Agent Development Standards** — Read `cache/wiki/domain_agents.md`
  Load when: working on AI agents, LLM integration, or agent deployment
- **Service: data-intake** — Read `cache/wiki/data-intake.md`
  Load when: working in data-intake repo or referencing its dependencies
```

## Data Flow

### Pull Flow (Session Start)

```
Session Start
    │
    ▼
UserPromptSubmit Hook (Claude Code built-in)
    │
    ├─── Check cache age (30 min wiki, 24 hr skills)
    │
    ├─── If stale: pull from wiki ──► team_knowledge.md
    │         (Tiers 1-2 inlined + Tiers 3-4 as Read-tool pointers)
    │
    ├─── If stale: git pull skills repo
    │         │
    │         └─── Generate skills_routing.md from SKILL.md frontmatter
    │
    └─── CLAUDE.md imports via @-syntax:
              @team_knowledge.md
              @skills_routing.md
              @rules/team-standards.md
```

### Push Flow (Learning Detected)

```
Claude detects new learning
    │
    ▼
Present Knowledge Entry ──► User reviews
    │                           │
    │                      [approve / edit / skip]
    │                           │
    ▼                           ▼
Route to target page      (if approved)
    │
    ├─── Team standard?     ──► Shared standards page
    ├─── Cross-service dep? ──► Dependency map page
    ├─── Domain rule?       ──► Domain page
    └─── Module-specific?   ──► Module detail page
              │
              ▼
    Stage in "Recent Learnings" section
              │
              ▼
    Push via wiki API
              │
              ▼
    Clear local cache (force fresh pull next session)
```

## How It Loads: The Zero-Keystroke Chain

Here's exactly what happens between "start a Claude Code session" and "Claude already knows your team's standards" — before you type a single character.

### Step 1: The Hook Fires

Claude Code supports `UserPromptSubmit` hooks in `~/.claude/settings.json`. This hook runs a script **every time the user sends a message** — including the very first one:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/scripts/pull_knowledge.sh 2>/dev/null || true"
          }
        ]
      }
    ]
  }
}
```

The hook fires before Claude processes the user's prompt. By the time Claude starts thinking, the knowledge is already on disk.

### Step 2: The Pull Script Syncs Knowledge

`pull_knowledge.sh` does two things:

**Wiki sync** (30-minute cache TTL, currently uses Confluence REST API):
```
1. Check if ~/.claude/team_knowledge.md exists and is < 30 min old
2. If fresh → skip (instant, no network call)
3. If stale → call Confluence API:
   a. Pull shared standards page (Tier 1)
   b. Pull dependency map page (Tier 2)
   c. Pull domain pages (Tier 4) — cached individually
   d. Pull module detail pages (Tier 3) — cached individually
   e. Assemble team_knowledge.md: inline Tiers 1-2, add Read-tool pointers for Tiers 3-4
   f. All pages also cached at ~/.claude/cache/wiki/ for on-demand access
```

**Skills sync** (24-hour cache TTL):
```
1. Check if skills repo was pulled in the last 24 hours
2. If fresh → skip
3. If stale → git pull the central skills repo
4. Parse all SKILL.md files for YAML frontmatter (name + description)
5. Generate routing table: ~/.claude/cache/skills_routing.md
```

### Step 3: CLAUDE.md Imports via `@`-syntax

Claude Code has a built-in feature: any line in CLAUDE.md starting with `@` followed by a file path is **automatically imported into context**. The file's contents are loaded as if they were part of CLAUDE.md itself.

```markdown
# My CLAUDE.md

## Who I Work With
- Name: Jane Smith
- Role: Data Engineer

## How to Work
- Check the skill routing table before every response
- Auto-invoke skills when intent matches

## Team Standards
@~/.claude/rules/team-standards.md

## Skill Routing
@~/.claude/cache/skills_routing.md

## Team Knowledge (synced from wiki)
@~/.claude/team_knowledge.md
```

When Claude Code loads this CLAUDE.md, it resolves every `@` line by reading the referenced file and injecting its contents. The result is a single, assembled context that includes:
- Your personal config (10-30 lines)
- Team standards (Tier 1, ~50 lines)
- Skill routing table (~80-130 lines)
- Team knowledge: shared standards + dependency map (Tiers 1-2, ~250 lines inlined) + pointers for Tiers 3-4

**Total: ~410 lines loaded before you type anything. Tiers 3-4 loaded on-demand.**

### Step 4: On-Demand References (Tiers 3-4)

Not everything loads upfront. The team knowledge file includes **pointers** that tell Claude when to load additional context:

```markdown
## On-Demand Detail Sections
- **Agent Development Standards** — Read `~/.claude/cache/wiki/domain_agents.md`
  Load when: working on AI agents or LLM integration
- **Service: data-intake** — Read `~/.claude/cache/wiki/data-intake.md`
  Load when: working in data-intake repo or referencing its dependencies
```

Claude uses its `Read` tool to load these on-demand — only when a task needs them. This is how you can index 2000+ lines of reference material without loading it all upfront.

### The Complete Chain

```
Session start
  │
  ▼
Hook fires pull_knowledge.sh ──► Checks cache age
  │                                   │
  │                              Fresh? → Skip (0ms)
  │                              Stale? → Pull from wiki (500ms)
  │                                        │
  │                                        ▼
  │                                   Assemble team_knowledge.md
  │                                   Cache module pages individually
  │                                   Generate skills_routing.md
  │
  ▼
Claude Code loads CLAUDE.md
  │
  ├── Resolves @team_knowledge.md → injects wiki content
  ├── Resolves @skills_routing.md → injects skill table
  ├── Resolves @rules/team-standards.md → injects standards
  │
  ▼
Claude processes user's first prompt
  │
  └── Already has: team standards, dependency map,
      skill routing + pointers for module detail — zero questions asked
```

**The user types their first prompt. Claude already knows everything the team knows.**

## Design Principles

### 1. Progressive Disclosure
Don't dump 2000 lines into context. Load ~250 lines (Tiers 1-2) always, and include pointers for Tiers 3-4 that Claude reads on-demand. This keeps the context window efficient while ensuring the AI never lacks critical information.

### 2. Wiki as Source of Truth
Local files are caches, not sources. Your wiki (Confluence, Notion, etc.) is authoritative. This means:
- Multiple team members see the same knowledge
- Learnings pushed by one person benefit everyone
- No merge conflicts on knowledge files
- Wiki versioning provides audit trail

### 3. Auto-Generation Over Manual Maintenance
Anything derivable from source files should be auto-generated:
- Skill routing table → generated from SKILL.md frontmatter
- Module detail sections → pulled from wiki (maintained via push protocol)
- Team knowledge file → assembled from wiki pages

Manual maintenance drifts. We proved this: our manually-maintained routing table had 7 missing skills and 1 phantom entry.

### 4. Structured Push, Never Ad-Hoc
Learnings don't get dumped randomly into wiki pages. The push protocol ensures:
- Every learning is categorized and routed to the right page
- Learnings stage in "Recent Learnings" before promotion to permanent sections
- User approval gates every write
- Version messages track what changed and why

### 5. Cache Hierarchy
```
Check local file (instant, 0ms)
  └─► Miss? Check pre-cached wiki page (~50ms disk read)
        └─► Miss? Call wiki API (~500ms network)
```

This prevents unnecessary API calls while ensuring freshness.

## Context Window Budget

| Component | Lines | Loaded |
|-----------|-------|--------|
| CLAUDE.md (base) | ~30 | Always |
| Team Standards (Tier 1) | ~50 | Always |
| Skill Routing | ~130 | Always |
| Dependency Map (Tier 2) | ~200 | Always |
| **Total always loaded** | **~410** | **Every session** |
| Module Detail (Tier 3) | ~100/repo | On-demand (pointers in team_knowledge.md) |
| Domain/References (Tier 4) | ~100-300 | On-demand (pointers in team_knowledge.md) |

Claude Code's context window is large enough that 410 lines of always-loaded knowledge is a worthwhile tradeoff — it prevents far more wasted context from re-explaining things. Tiers 3-4 are pre-cached locally and loaded via Read tool when the task needs them.
