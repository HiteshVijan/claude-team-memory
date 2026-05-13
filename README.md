<p align="center">
  <h1 align="center">Context Memory for Claude Code</h1>
  <p align="center">
    <strong>Give your entire team an AI assistant that already knows your standards, dependencies, and hard-won operational knowledge — from Day 1.</strong>
  </p>
  <p align="center">
    <a href="#quick-start"><img src="https://img.shields.io/badge/setup-5_minutes-brightgreen" alt="Setup time"></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT License"></a>
    <a href="docs/architecture.md"><img src="https://img.shields.io/badge/tiers-4_layer_architecture-orange" alt="Architecture"></a>
    <a href="docs/push-protocol.md"><img src="https://img.shields.io/badge/flow-bidirectional-purple" alt="Bidirectional"></a>
    <a href="#wiki-setup"><img src="https://img.shields.io/badge/wiki-Confluence_%7C_Notion_%7C_GitBook-lightgrey" alt="Wiki Support"></a>
  </p>
</p>

---

## Why Teams Need This

Most AI coding memory tools help **one developer** remember their preferences. But teams have a bigger problem:

> Your team has spent months building institutional knowledge — coding standards, service dependencies, contact directories, pipeline runbooks, hard-won debugging fixes. **None of it survives into the AI session.**

Every morning, every developer on your team re-explains the same things. The AI gives different answers to different people. New team members start from absolute zero. And when someone spends 4 hours debugging a pipeline issue, that knowledge dies when the session ends.

**Context Memory connects Claude Code to your team's wiki.** One teammate installs it in 5 minutes. The entire team's knowledge loads automatically into every session — before anyone types a single character.

### The Results

From daily use across a 14-repo engineering ecosystem:

| Metric | Before | After |
|--------|--------|-------|
| **Session setup time** | 10-15 min re-explaining context | **~0** (auto-loaded from wiki) |
| **Wrong environment errors** | Weekly occurrence | **Near zero** |
| **New teammate onboarding** | ~2 weeks to be productive with AI | **Day 1** |
| **Knowledge captured** | Lost when session ends | **Pushed to wiki, shared with team** |
| **Cross-repo awareness** | "I didn't know that table was shared" | **Auto-loaded dependency map** |
| **Skill routing drift** | 7 missing + 1 phantom skill | **Zero drift** (auto-generated) |

---

## How It's Different

| Feature | Individual Memory Tools | Context Memory |
|---------|----------------------|----------------|
| **Scope** | Single developer's preferences | Entire team's institutional knowledge |
| **Source of truth** | Local files on one machine | Your wiki (Confluence, Notion, GitBook) — shared |
| **Cross-repo awareness** | None | Full dependency map — repos, workflows, shared tables, data lineage |
| **Knowledge direction** | One-way (read from config) | **Bidirectional** (auto-pull from wiki + push learnings back) |
| **Skill routing** | Manual slash commands | Auto-generated from YAML metadata — zero drift |
| **New team member** | Starts from zero | Day 1: AI already knows what the team knows |
| **When someone learns something** | Dies with the session | Staged → reviewed → pushed to wiki → everyone gets it |

> **See it in action:** [Before & After — two real sessions, same question, dramatically different results](docs/before-after.md)

---

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                     Claude Code Session                         │
│                                                                 │
│  ┌───────────────┐  ┌───────────────┐  ┌──────────────────┐    │
│  │ Tier 1: Team  │  │ Tier 2: Deps  │  │ Tier 3: Module   │    │
│  │ Standards     │  │ & Lineage     │  │ Detail (per-repo)│    │
│  │ ~50 lines     │  │ ~200 lines    │  │ ~100 lines       │    │
│  │ ALWAYS loaded │  │ ALWAYS loaded │  │ AUTO loaded      │    │
│  └───────────────┘  └───────────────┘  └──────────────────┘    │
│                                                                 │
│  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐  │
│    Tier 4: On-Demand References (loaded when task needs it)     │
│  └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘  │
└────────────────────────────┬────────────────────────────────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
       ┌────────────┐ ┌───────────┐ ┌────────────┐
       │    Wiki     │ │  Skills   │ │   GitHub   │
       │ Confluence  │ │   Repo    │ │   (Code)   │
       │ Notion      │ └───────────┘ └────────────┘
       │ GitBook     │
       └──────┬──────┘
              │
         Bidirectional:
         PULL on session start (auto)
         PUSH learnings back (user-approved)
```

**~560 lines of team knowledge load into every session.** No database, no infra — just markdown files, a shell hook, and your existing wiki.

> **Under the hood:** See the full [code-level architecture diagram](diagrams/architecture.mmd) and [architecture deep dive](docs/architecture.md) for the complete flow from `settings.json` hook → `pull_knowledge.sh` → wiki API → cache → `@`-imports → Claude Code context.

### The `@`-import mechanism

Claude Code has a built-in feature: any line in `CLAUDE.md` starting with `@` followed by a file path is **automatically imported into context**. The file's contents load as if they were part of CLAUDE.md itself:

```markdown
## Team Standards
@~/.claude/rules/team-standards.md       ← this file's contents are injected here

## Skill Routing
@~/.claude/cache/skills_routing.md       ← and this one here

## Team Knowledge
@~/.claude/team_knowledge.md             ← and this one here
```

This is how ~560 lines of team knowledge load into every session — Claude Code resolves the `@` references on startup.

### Every session start (automatic)

```
UserPromptSubmit hook fires (before Claude processes the first prompt)
  │
  ├── Wiki stale? (>30 min) → Pull team standards + dependency map + module detail
  ├── Skills stale? (>24 hr) → Git pull skills repo
  ├── Generate skill routing table from SKILL.md YAML frontmatter
  │
  └── CLAUDE.md imports everything via @-syntax:
        @team_knowledge.md       ← assembled from wiki pages
        @skills_routing.md       ← auto-generated, zero drift
        @rules/standards.md      ← team guardrails
```

### When Claude learns something new (user-approved)

```
Claude detects a new learning
  │
  ├── Presents a structured knowledge entry:
  │     Title, category, scope, problem/solution
  │
  ├── User reviews: [approve / edit / skip]
  │
  ├── Routes to the right wiki page:
  │     Team standard? → Shared page
  │     Cross-service dependency? → Dependency map
  │     Module-specific fix? → That repo's detail page
  │
  ├── Stages in "Recent Learnings" section (never inline)
  │
  └── Pushes via wiki API → clears local cache
```

The staging area has lifecycle rules: max 10 entries per page, promote/delete/keep reviews, 30-day age flags. See [push-protocol.md](docs/push-protocol.md) for the full flow.

### Skill routing auto-generation

Instead of a manually-maintained routing table that drifts:

```
SKILL.md files (YAML frontmatter)     →     Generated routing table
┌──────────────────────────┐                ┌──────────────────────────────┐
│ name: bigquery            │                │ /bigquery — Query tables,    │
│ description: >            │   generator    │   explore schemas, validate  │
│   Query tables, explore   │ ──────────►    │   data using BigQuery        │
│   schemas, validate data  │                │                              │
└──────────────────────────┘                └──────────────────────────────┘
   Handles >, >-, | multiline
```

On first run, this caught 7 missing skills and 1 phantom entry in our routing table. See [skills-guide.md](docs/skills-guide.md) for the full SKILL.md format and progressive disclosure model.

---

## Quick Start

### One-liner install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HiteshVijan/claude-team-memory/main/scripts/quick-install.sh)
```

This creates the directory structure, installs the session hook, and generates your initial CLAUDE.md.

### Or step by step

```bash
# 1. Clone
git clone https://github.com/HiteshVijan/claude-team-memory.git ~/.claude/repos/claude-team-memory

# 2. Install
cd ~/.claude/repos/claude-team-memory && bash framework/install.sh

# 3. Configure your wiki connection
cp examples/wiki-pages.json ~/.claude/wiki-pages.json
# Edit with your page IDs

# 4. Verify
bash ~/.claude/scripts/pull_knowledge.sh
```

Start a new Claude Code session — your team knowledge is now in every conversation. For a detailed walkthrough, see the [30-minute tutorial](docs/tutorial.md).

<a name="wiki-setup"></a>
### Wiki setup

<details>
<summary><strong>Confluence</strong> (fully supported)</summary>

```bash
mkdir -p ~/.config/confluence
cat > ~/.config/confluence/.env << 'EOF'
CONFLUENCE_BASE_URL=https://your-org.atlassian.net
CONFLUENCE_USERNAME=your.email@company.com
CONFLUENCE_API_TOKEN=your-api-token
EOF
```
</details>

<details>
<summary><strong>Notion</strong> (planned — contributions welcome)</summary>

Notion adapter is planned. The architecture is wiki-agnostic — adapting `pull_knowledge.sh` to Notion requires ~20 lines of API code. See [CONTRIBUTING.md](CONTRIBUTING.md).

```bash
mkdir -p ~/.config/notion
cat > ~/.config/notion/.env << 'EOF'
NOTION_API_KEY=your-notion-api-key
EOF
```
</details>

<details>
<summary><strong>GitBook / Git-hosted markdown</strong> (planned — contributions welcome)</summary>

GitBook adapter is planned. For git-hosted markdown wikis, the pull script can be adapted to `git clone` instead of API calls. Contributions welcome.

```bash
mkdir -p ~/.config/gitbook
cat > ~/.config/gitbook/.env << 'EOF'
GITBOOK_REPO_URL=https://github.com/your-org/team-wiki.git
EOF
```
</details>

---

## Why I Built This

I work across 14+ repositories. Every morning, my AI assistant asked the same questions: *"Which project ID?" "Which branch is prod?" "Who do I contact for this?"*

But the real pain was deeper:
- **Multiple SOPs to check.** Every task required looking at 3-5 different wiki pages, runbooks, and contact directories before I could even start.
- **"Who do I contact?"** Pipeline failure? One person. Infrastructure issue? Different team. Deployment approval? Yet another. I spent more time hunting for the right contact than solving the actual problem.
- **Lost learnings.** A teammate spent 4 hours debugging a CLI issue. Found the fix. Knowledge died when the session ended. Three weeks later, I hit the exact same issue.

So I built Context Memory — first for myself (a big CLAUDE.md file), then added wiki sync (so it stays fresh), then added the push protocol (so learnings flow back). It spread to my team, then to other teams.

> **Full story:** [Why I Built Context Memory](docs/origin-story.md)

---

## Why This Matters at Scale

### For Individual Developers
Your AI assistant remembers your standards, your project IDs, your branch strategy. No more re-explaining every morning.

### For Teams
Everyone gets the same answers. New team member joins? Day 1, their AI already knows what took the rest of the team months to build. When one person discovers a fix, the entire team has it next session.

### For Cross-Team Collaboration
Teams that share tables, APIs, or pipelines need cross-repo awareness. The dependency map means your AI knows that changing `core_records` breaks three downstream services — before you push.

```
Team A publishes standards → Wiki ← Team B pulls automatically
Team B discovers a gotcha → Pushes to wiki → Team A gets it next session
```

### For Enterprise / Organization
- **Day 1 onboarding:** New hires install one command. Their AI immediately knows every standard, every contact, every pipeline dependency across the org
- **Knowledge retention:** When someone leaves, their learnings stay in the wiki — not in a private CLAUDE.md on their laptop
- **Audit trail:** Every push to wiki is versioned with a message. You can trace when a standard was added and by whom
- **Consistent AI outputs:** Every developer across every team gets the same guardrails, the same coding standards, the same environment config

## Scaling: Individual → Team → Organization

| Level | Setup Time | What You Get |
|-------|-----------|-------------|
| **Tier 0: Individual** | 30 min | Personal CLAUDE.md with your role, preferences, project context |
| **Tier 1: Team Standards** | 2-4 hrs | Shared coding rules, env config, branch strategy — consistent AI outputs across the team |
| **Tier 2: Dependency Map** | 4-8 hrs | Cross-service topology — every repo, workflow, and shared table indexed |
| **Tier 3: Skill Library** | 2-4 hrs/skill | Auto-invoked skills from YAML metadata — zero-maintenance routing |
| **Tier 4: Organization** | Ongoing | Cross-team knowledge sharing, enterprise skill catalog, Day 1 onboarding for every new hire |

See [adoption-guide.md](docs/adoption-guide.md) for the full rollout plan with metrics.

## Not For You If

- **You work solo on small projects** — a single CLAUDE.md file is enough. You don't need team sync.
- **You don't have a wiki** — the bidirectional flow needs a shared knowledge base. Start with Tier 0 (just CLAUDE.md) and grow from there.
- **You want a plug-and-play AI memory** — this is a framework, not a product. You'll spend 2-4 hours setting up team standards and dependency maps. The payoff is compounding, but the setup is real work.
- **Your team is < 3 people** — the ROI of shared context increases with team size. Below 3, verbal communication might be faster.

---

## Repository Structure

```
claude-team-memory/
├── docs/
│   ├── architecture.md                 # 4-tier knowledge architecture (deep dive)
│   ├── adoption-guide.md               # Scaling from individual to org
│   ├── push-protocol.md               # Bidirectional push flow + staging lifecycle
│   ├── before-after.md                 # Side-by-side session comparison
│   ├── tutorial.md                     # Your first 30 minutes (hands-on)
│   ├── skills-guide.md                # Skills setup, YAML frontmatter, progressive disclosure
│   ├── origin-story.md                # Why I built this
│   └── live-demo.md                   # Set up a live demo with your own wiki
├── framework/
│   ├── install.sh                      # One-command installer with team pack support
│   ├── claude-base.md.tmpl             # Base CLAUDE.md template
│   ├── team-pack.md.tmpl              # Team-specific template
│   └── rules/
│       └── team-standards.md           # Starter team standards (installed to ~/.claude/rules/)
├── team-packs/
│   └── example-team/                   # Example team pack (copy and customize for your team)
│       ├── team.env                    # Team-specific variables
│       └── claude-team.md.tmpl         # Team-specific CLAUDE.md section
├── scripts/
│   ├── quick-install.sh                # One-liner bootstrap script
│   ├── pull_knowledge.sh               # Wiki sync + skill routing generator
│   └── generate_skill_routing.py       # Standalone routing table generator
├── examples/
│   ├── CLAUDE.md                       # Example CLAUDE.md with @-imports
│   ├── team-knowledge.md               # Example team knowledge (standards + dependency map)
│   ├── wiki-pages.json                 # Example wiki-to-repo mapping
│   ├── skills-routing.md              # Example auto-generated routing table
│   └── skills/bigquery/SKILL.md       # Example skill with YAML frontmatter
└── diagrams/
    └── architecture.mmd                # Mermaid source for architecture diagram
```

## Key Design Decisions

1. **Files over databases** — markdown and JSON. No infra to manage, no vendor lock-in.
2. **Progressive disclosure** — ~560 lines always loaded, the rest on demand. Respects the context window.
3. **Wiki as source of truth** — local files are caches. One edit on the wiki benefits every teammate next session.
4. **Auto-generation over manual maintenance** — skill routing derived from SKILL.md files, not a hand-maintained table.
5. **Push requires approval** — AI proposes learnings, humans approve every write. No auto-push to your wiki.
6. **Wiki-agnostic architecture** — Confluence today, Notion and GitBook adapters are thin and easy to add.

## Prerequisites

- **Claude Code** — version with `UserPromptSubmit` hooks and `@`-import support (2025+)
- **Python 3.6+** — for the YAML frontmatter parser and HTML-to-markdown converter
- **bash** — macOS or Linux (Windows users: use WSL)
- **curl + git** — for wiki API calls and skills repo sync

## Contributing

- **Wiki adapters** — pull/push functions for Notion, GitBook, Backstage, or other platforms
- **Team packs** — configurations for different team types (frontend, ML, platform, SRE)
- **Skill categories** — additional groupings for the routing generator
- **Docs & examples** — better onboarding material, video walkthroughs

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

MIT — see [LICENSE](LICENSE).

---

<p align="center">
  <em>Built by a data engineering team that got tired of re-explaining the same things to AI every morning.</em>
</p>
