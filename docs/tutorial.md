# Tutorial: Your First 30 Minutes with Context Memory

This walkthrough takes you from zero to a working Context Memory setup. We'll use a fictional team ("Analytics Platform") to keep things concrete.

---

## Minute 0-5: Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HiteshVijan/claude-team-memory/main/scripts/quick-install.sh)
```

You now have:
```
~/.claude/
├── CLAUDE.md                    ← your personal config (edit this)
├── wiki-pages.json              ← wiki page mapping (edit this)
├── scripts/pull_knowledge.sh    ← auto-runs on session start
├── cache/                       ← where synced knowledge lives
└── rules/                       ← team standards go here
```

## Minute 5-10: Personalize Your CLAUDE.md

Open `~/.claude/CLAUDE.md` and fill in the placeholders:

```markdown
## Who I Work With
- Name: Jane Smith
- Role: Data Engineer, Analytics Platform team
- Email: jane.smith@acme.com
```

The `@`-import lines at the bottom pull in shared files automatically:
```markdown
@~/.claude/rules/team-standards.md       ← shared team rules
@~/.claude/cache/skills_routing.md       ← auto-generated skill routing
@~/.claude/team_knowledge.md             ← synced from wiki
```

You don't need to edit these — they're populated by the pull script.

## Minute 10-15: Create Your Team Standards

Create `~/.claude/rules/team-standards.md` — this is Tier 1, loaded into every session:

```markdown
# Analytics Platform — Team Standards

## Environment Config
- Dev:  `acme-dev.analytics_dev`
- Prod: `acme-prod.analytics_prod`
- Never use `acme-compute-dev` — that's Compute, not Storage

## Git Workflow
- PR target: always `develop`, never `main`
- `main` is PROD — check `origin/main` for current prod state
- Branch naming: TICKET-NUMBER-short-description (flat hyphens)

## Cost Labels (required on ALL queries)
- team=analytics, costcenter=550100, project=analytics-platform

## Query Standards
- All CREATE TABLE must include OPTIONS block with expiration + labels
- All queries must start with SET @@query_label statements
- Use parameterized project/dataset references: `{{target_schema}}`
```

**That's it for Tier 1.** Every Claude Code session now loads these rules automatically.

## Minute 15-20: Set Up Wiki Sync (Optional but Powerful)

If your team has a wiki, connect it so knowledge stays in sync.

### Step 1: Add wiki credentials

```bash
mkdir -p ~/.config/confluence
cat > ~/.config/confluence/.env << 'EOF'
CONFLUENCE_BASE_URL=https://your-org.atlassian.net
CONFLUENCE_USERNAME=jane.smith@acme.com
CONFLUENCE_API_TOKEN=your-api-token-here
EOF
```

### Step 2: Map your repos to wiki pages

Edit `~/.claude/wiki-pages.json`:

```json
{
  "_meta": {
    "wiki_provider": "confluence",
    "wiki_base_url": "https://your-org.atlassian.net",
    "space_key": "ANALYTICS",
    "shared_page_id": "YOUR_SHARED_PAGE_ID",
    "dependency_map_page_id": "YOUR_DEPMAP_PAGE_ID"
  },
  "repos": {
    "feature-engine": {
      "page_id": "YOUR_FEATURE_ENGINE_PAGE_ID",
      "domain": "batch-processing"
    }
  }
}
```

Replace the `YOUR_*` placeholders with real Confluence page IDs (find them in the page URL).

### Step 3: Test the pull

```bash
bash ~/.claude/scripts/pull_knowledge.sh
cat ~/.claude/team_knowledge.md
```

You should see your wiki content pulled and assembled into a local file.

## Minute 20-25: Add a Dependency Map (Tier 2)

Create a wiki page with your cross-service topology. When you run `pull_knowledge.sh`, it pulls this page and assembles it into `~/.claude/team_knowledge.md` automatically. (Don't edit `team_knowledge.md` directly — it's a cache file that gets overwritten on each pull.)

Example dependency map content for your wiki page:

```markdown
# Dependency Map

## Service Registry
| Repo | Purpose | Key Workflows |
|---|---|---|
| data-intake | Raw data ingestion | WF-10, WF-11 |
| data-transform | Daily preprocessing | WF-20, WF-21 |
| feature-engine | Feature scoring | WF-30 |
| data-export | Downstream delivery | WF-40 |

## Data Lineage
| Table | Producing Service | Consuming Services |
|---|---|---|
| raw_events | data-intake | data-transform |
| core_records | data-transform | feature-engine, data-export |
| enriched_features | feature-engine | data-export, analytics-agent |

## Quick Reference
| Working On | Also Check |
|---|---|
| Schema change in data-transform | ALL downstream services |
| New feature in feature-engine | data-export (downstream impact) |
```

This is Tier 2 — Claude now knows which services depend on each other and can warn you about downstream impact.

## Minute 25-30: Test It

Start a new Claude Code session and try these:

### Test 1: Standards are loaded
```
You: What project ID should I use for dev queries?

Claude: Use acme-dev.analytics_dev. Never use acme-compute-dev —
        that's the Compute project, not Storage.
```

If Claude answers correctly without you explaining, Tier 1 is working.

### Test 2: Dependency awareness
```
You: I'm changing the schema of core_records in data-transform

Claude: Be careful — core_records is consumed by feature-engine
        and data-export. A schema change here impacts both.
        Want me to check what columns they reference?
```

If Claude knows the downstream consumers, Tier 2 is working.

### Test 3: Skill routing (if you have skills)
```
You: Check if the raw_events table has data for today

Claude: *auto-invokes /bigquery skill*
        Running query...
```

If Claude auto-invokes the right skill without you typing `/bigquery`, skill routing is working.

## What's Next

You now have a working Tier 1 + Tier 2 setup. Here's where to go from here:

| Next Step | Time | Guide |
|-----------|------|-------|
| Add module detail pages for each repo (Tier 3) | 1-2 hrs/repo | [architecture.md](architecture.md) |
| Set up the push protocol to capture learnings | 30 min | [push-protocol.md](push-protocol.md) |
| Build team-specific skills | 2-4 hrs/skill | See `scripts/generate_skill_routing.py` |
| Roll out to teammates | 30 min/person | [adoption-guide.md](adoption-guide.md) |
| Set up the full bidirectional flow | 1-2 hrs | [push-protocol.md](push-protocol.md) |

## Troubleshooting

### "team_knowledge.md is empty"
- Check wiki credentials: `cat ~/.config/confluence/.env`
- Check page IDs: `cat ~/.claude/wiki-pages.json`
- Run manually with verbose output: `bash -x ~/.claude/scripts/pull_knowledge.sh`

### "Skill routing table is empty"
- Check skills directory exists: `ls ~/.claude/skills/`
- Each skill needs a `SKILL.md` with YAML frontmatter (`name:` and `description:`)
- Run the generator manually: `python3 scripts/generate_skill_routing.py`

### "Claude doesn't seem to know my standards"
- Verify CLAUDE.md has `@`-imports: `grep "^@" ~/.claude/CLAUDE.md`
- Check the imported files exist: `ls ~/.claude/rules/team-standards.md`
- Start a **new** session (changes only take effect on session start)

### "Hook isn't firing on session start"
- Check settings.json: `cat ~/.claude/settings.json`
- Should have a `UserPromptSubmit` hook pointing to `pull_knowledge.sh`
- The hook runs silently — check `~/.claude/cache/` for recently-modified files
