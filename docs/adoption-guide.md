# Context Memory — Adoption Guide

How to roll out Context Memory from a single developer to an entire engineering organization.

---

## Who Benefits

Context Memory isn't just for engineers who write code with Claude Code. Anyone who interacts with the AI assistant — or manages people who do — benefits from persistent institutional knowledge.

| Role | Without Context Memory | With Context Memory |
|------|----------------------|-------------------|
| **Engineering Lead** | No visibility into what AI sessions produce; inconsistent outputs across team | Standardized guardrails load automatically; learnings flow back to the wiki |
| **Software Engineer** | Re-explains service schemas, dependencies, and coding standards every session | Standards, service topology, and cross-repo dependencies are pre-loaded |
| **Data Scientist** | AI doesn't know the team's transformation rules; outputs need heavy review | AI follows the same standards the engineering team uses |
| **Project Manager** | Can't leverage AI for status checks without explaining project context each time | AI knows the ticket system, tracking tools, and project structure |
| **Business Analyst** | AI gives generic answers without domain context | AI understands the team's domain terminology and business rules |
| **New Team Member** | Spends weeks learning tribal knowledge that isn't written down | Day 1: AI assistant already knows what the team knows |

## Adoption Tiers

### Tier 0: Individual Developer (1 hour setup)

**What you get:** Personal CLAUDE.md with your role, preferences, and project context.

**Steps:**
1. Create `~/.claude/CLAUDE.md` with your name, role, and team
2. Add your coding standards and conventions
3. Add links to key resources (wiki pages, dashboards, repos)

**Impact:** 5-10 minutes saved per session from not re-explaining who you are and what you work on.

### Tier 1: Team Knowledge (2-4 hours setup)

**What you get:** Shared team standards that load for every team member.

**Steps:**
1. Create a wiki page with your team's standards (env config, git workflow, coding rules)
2. Set up the pull script to sync the wiki page on session start
3. Create a wiki page mapping config (`wiki-pages.json`) for your repos
4. Share the setup script with your team

**Works with:** Confluence, Notion, GitBook, or even a markdown file in a git repo.

**Impact:** Consistent AI outputs across the team. No more "the AI told me to use the wrong project ID."

### Tier 2: Dependency Map (4-8 hours setup)

**What you get:** Cross-service topology map — every repo, workflow, and shared table indexed.

**Steps:**
1. Create a Dependency Map wiki page with three tables: Service Registry, Workflow Dependencies, Data Lineage
2. Create module detail pages for each repo (task chains, query files, business context)
3. Update the pull script to include dependency map and module pages
4. Add a "Working on X? Also check Y" quick reference

**Impact:** AI understands cross-service impact of changes. "If I modify this table schema, what breaks downstream?"

### Tier 3: Skill Library (2-4 hours per skill)

**What you get:** Auto-invoked skills that match user intent to specialized workflows.

**Steps:**
1. Create a central skills repo with `SKILL.md` files (YAML frontmatter + instructions)
2. Set up the routing table auto-generator
3. Install the UserPromptSubmit hook to pull skills on session start
4. Build team-specific skills for your common workflows

**Impact:** Team members don't need to remember slash commands. The AI auto-detects intent and invokes the right skill.

### Tier 4: Organization-Wide (ongoing)

**What you get:** Cross-team knowledge sharing, enterprise skill catalog, standardized onboarding.

**Steps:**
1. Create team packs for each team (templates + team-specific config)
2. Establish a central skills repo with contributions from multiple teams
3. Set up the wiki push protocol so learnings flow back automatically
4. Create an adoption playbook for new teams

**Impact:** Every new team member, on every team, gets an AI assistant that already knows the organization.

## Implementation Patterns

### Pattern 1: The Knowledge Pull Loop

```
Wiki Page ──pull──► Local Cache ──@import──► Claude Context
    ▲                                            │
    │                                            │
    └──────────push (user-approved)──────────────┘
```

Knowledge flows in a loop:
1. Wiki is the source of truth (any wiki — Confluence, Notion, GitBook, git-hosted markdown)
2. Pull script caches it locally on session start
3. CLAUDE.md imports the cache via `@` syntax
4. When Claude learns something new, it proposes pushing back to the wiki
5. After user approval, the wiki is updated
6. Next session pulls the updated knowledge

### Pattern 2: The Skill Routing Table

Instead of maintaining a manual mapping of "user intent → skill to invoke":

```
SKILL.md (frontmatter)          Generated Routing Table
┌─────────────────────┐         ┌──────────────────────────────┐
│ name: bigquery       │  ──►   │ /bigquery — Query tables,    │
│ description: Query   │        │   explore schemas, validate  │
│   tables, explore... │        │   data using BigQuery        │
└─────────────────────┘         └──────────────────────────────┘
```

The generator script reads all SKILL.md files, parses the YAML (handles `>`, `>-`, `|` multiline formats), groups by category, and writes a markdown table. Zero drift.

### Pattern 3: Progressive Disclosure

Don't load everything. Use a tiered loading strategy:

```python
# Always loaded (cheap, high-value)
team_standards = "50 lines of guardrails"
dependency_map = "200 lines of topology"

# Loaded per-repo (medium cost, contextual)
module_detail = "100 lines for current repo"

# Loaded on-demand (expensive, task-specific)
domain_references = "only when task matches"
```

The `team_knowledge.md` file includes pointers for on-demand sections:
```markdown
## On-Demand References
- **Agent Development** — Read `cache/wiki/domain_agents.md`
  Load when: working on AI agents or LLM integration
```

## Common Objections

### "This is too much context — won't it slow Claude down?"

No. The baseline is ~560 lines. Claude Code's context window handles millions of tokens. 560 lines of high-signal knowledge is a better use of context than the alternative: 1000+ lines of the user manually re-explaining things every session.

### "What if the wiki gets stale?"

The push protocol keeps it fresh. Every session can push learnings back. The pull script has cache TTLs (30 min for wiki, 24 hr for skills). And stale knowledge is still better than no knowledge — it provides a starting point that Claude can verify against the current codebase.

### "We don't use Confluence."

The architecture is wiki-agnostic. The pull script currently ships with a Confluence adapter, but adapting it to Notion, GitBook, or even a Git-hosted markdown repo requires changing ~20 lines in the pull function. The caching layer, `@`-imports, skill routing, and push protocol all work the same regardless of wiki backend.

### "How is this different from just putting everything in CLAUDE.md?"

Three ways:
1. **Shared source of truth** — CLAUDE.md is per-developer. Wiki pages are shared across the team.
2. **Auto-sync** — CLAUDE.md is static. Context Memory auto-pulls fresh knowledge every session.
3. **Bidirectional** — CLAUDE.md is read-only input. Context Memory pushes learnings back to the wiki.

### "What about sensitive information?"

The framework syncs from your organization's internal wiki — it doesn't expose anything externally. The push protocol requires user approval for every write. Local cache files follow the same access controls as your development environment.

## Measuring Impact

Track these metrics before and after adoption:

| Metric | How to Measure |
|--------|---------------|
| **Session setup time** | Time from session start to first productive output |
| **Standards compliance** | % of AI outputs that follow team conventions without correction |
| **Cross-service accuracy** | % of cross-service questions answered correctly on first try |
| **Knowledge rediscovery** | Times per week someone re-explains something already documented |
| **Onboarding velocity** | Days until new team member is productive with AI assistant |

Teams that have adopted Context Memory report:
- 10-15 min saved per session on context re-establishment
- ~90% reduction in "wrong project ID" or "wrong branch target" errors
- New team members productive with AI assistant on Day 1 instead of Week 2

---

*Start with Tier 0 (30 minutes). If it helps, move to Tier 1 (half a day). The ROI compounds with each tier.*
