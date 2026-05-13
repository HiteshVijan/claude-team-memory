# Skills & Frontmatter Guide

How to create skills with YAML frontmatter, how the routing table auto-generation works, and how progressive disclosure keeps context lean.

---

## What Is a Skill?

A skill is a directory containing a `SKILL.md` file. Claude Code discovers skills automatically from `~/.claude/skills/` — each subdirectory with a `SKILL.md` becomes a slash command.

```
~/.claude/skills/
├── bigquery/
│   └── SKILL.md        ← /bigquery
├── architecture-design/
│   └── SKILL.md        ← /architecture-design
├── deploy-gke/
│   ├── SKILL.md        ← /deploy-gke
│   └── templates/      ← bundled resources
│       └── helm-values.yaml
└── data-pipeline/
    ├── SKILL.md        ← /data-pipeline
    └── examples/
        └── dag_template.py
```

## SKILL.md File Structure

Every SKILL.md has two parts: **YAML frontmatter** (metadata) and **markdown body** (instructions).

```markdown
---
name: bigquery
description: >
  Query tables, explore schemas, check data,
  run volume analysis using BigQuery
---

# BigQuery Skill

## When to Use
Use this skill when the user needs to query BigQuery tables...

## Instructions
1. Always use the dev project unless told otherwise
2. Include cost labels on every query
...
```

### Frontmatter Fields

| Field | Required | Purpose |
|-------|----------|---------|
| `name` | Yes | The slash command name (e.g., `bigquery` → `/bigquery`) |
| `description` | Yes | What the skill does — used for intent matching in the routing table |

The `description` is the most important field. It determines when the skill gets auto-invoked. Write it as a user-facing summary of what the skill can do.

### Multiline Description Formats

YAML supports several ways to write multi-line values. The routing table generator handles all of them:

#### Folded (`>`) — joins lines with spaces

```yaml
description: >
  Query tables, explore schemas, check data,
  run volume analysis, and validate entries
  using BigQuery
```

Result: `Query tables, explore schemas, check data, run volume analysis, and validate entries using BigQuery`

#### Folded strip (`>-`) — same as `>`, strips trailing newline

```yaml
description: >-
  Build and deploy AI agents using Google
  Agent Development Kit with Vertex AI
```

Result: `Build and deploy AI agents using Google Agent Development Kit with Vertex AI`

#### Literal (`|`) — preserves newlines

```yaml
description: |
  Line 1 stays on its own line
  Line 2 stays on its own line
```

Rarely used for descriptions (the routing table works best with single-line descriptions), but the parser supports it.

#### Simple single-line

```yaml
description: Render Mermaid diagrams to PNG images
```

The simplest option when the description fits on one line.

## Progressive Disclosure: How Skills Load

Not everything loads at once. Skills use a 3-level disclosure model:

```
Level 1: Metadata only (always loaded)
  ↓ User invokes the skill
Level 2: Full instructions (loaded on demand)
  ↓ Skill references bundled files
Level 3: Bundled resources (loaded on demand)
```

### Level 1: Metadata (Always Loaded)

The routing table generator reads **only the frontmatter** from every SKILL.md. This produces a compact table (~1-2 lines per skill) that's loaded into every session via `@`-import:

```markdown
## Skill Routing Table (Auto-Generated)

### Data Engineering
| Skill | When to invoke |
|-------|---------------|
| `/bigquery` | Query tables, explore schemas, check data, run volume analysis |
| `/data-pipeline` | Build and manage data pipelines with Airflow or Dataflow |
```

**Cost:** ~80-100 lines for 50+ skills. Loaded every session.

This is how Claude knows which skill to invoke without the user typing a slash command. The AI matches user intent against the "When to invoke" descriptions.

### Level 2: Full Instructions (On Invoke)

When a user invokes `/bigquery` (or Claude auto-invokes it), Claude Code reads the **full SKILL.md** — the markdown body below the frontmatter. This contains detailed instructions, rules, and examples.

**Cost:** 50-200 lines per skill. Only loaded when needed.

### Level 3: Bundled Resources (On Demand)

Skills can include additional files in their directory — templates, examples, reference data. These are only read when the skill's instructions reference them.

```
deploy-gke/
├── SKILL.md                      ← Level 2: instructions
├── templates/
│   ├── helm-values.yaml          ← Level 3: template
│   └── istio-gateway.yaml        ← Level 3: template
└── examples/
    └── deployment-checklist.md   ← Level 3: reference
```

**Cost:** Variable. Only loaded when the skill explicitly reads them.

### Why This Matters

Without progressive disclosure, loading 50 skills × 150 lines = 7,500 lines into every session. With it:

| What | Lines | When |
|------|-------|------|
| Routing table (all skills) | ~80 | Every session |
| Active skill instructions | ~150 | When invoked |
| Bundled resources | ~50-500 | When referenced |
| **Typical session total** | **~230** | |

That's a 97% reduction in context usage for skills.

## Creating a New Skill

### Step 1: Create the directory

```bash
mkdir -p ~/.claude/skills/my-new-skill
```

### Step 2: Write the SKILL.md

```markdown
---
name: my-new-skill
description: >
  One sentence describing what this skill does
  and when Claude should invoke it
---

# My New Skill

## When to Use
Describe the scenarios where this skill applies.

## Instructions
Step-by-step instructions for Claude when this skill is invoked.

1. First, check...
2. Then, do...
3. Finally, verify...

## Examples
Show example inputs and expected outputs.
```

### Step 3: Add to category mapping (optional)

Edit the `CATEGORIES` dict in `scripts/generate_skill_routing.py` to place your skill in a category:

```python
CATEGORIES = {
    "Data Engineering": [
        "bigquery", "data-pipeline", "my-new-skill",  # ← add here
    ],
    # ...
}
```

Skills not in any category list are placed in "Other".

### Step 4: Regenerate the routing table

```bash
python3 scripts/generate_skill_routing.py
```

This reads all SKILL.md files, parses frontmatter, groups by category, and writes the routing table to `~/.claude/cache/skills_routing.md`.

### Step 5: Test it

Start a new Claude Code session and describe a task that matches your skill's description — without using the slash command. If Claude auto-invokes the skill, the routing is working.

## How the Generator Works

```
1. Scan ~/.claude/skills/*/SKILL.md
2. For each file:
   a. Extract YAML frontmatter (between --- markers)
   b. Parse `name:` field
   c. Parse `description:` field (handling >, >-, |, |- multiline)
3. Look up each skill name in CATEGORIES dict → assign category
4. Group skills by category
5. Write markdown table to ~/.claude/cache/skills_routing.md
```

The generator runs automatically during `pull_knowledge.sh` (after skills repo pull), or manually via:

```bash
python3 scripts/generate_skill_routing.py --skills-dir ~/.claude/skills --output ~/.claude/cache/skills_routing.md
```

## Sharing Skills Across a Team

Skills live in a central Git repo that all team members pull from:

```
Central skills repo (Git)
  │
  ├── skills/
  │   ├── bigquery/SKILL.md
  │   ├── deploy-gke/SKILL.md
  │   └── ...
  │
  └── (pulled by each team member's session hook)

Team member's machine:
  ~/.claude/repos/skills-repo/     ← git clone
  ~/.claude/skills → symlink to → ~/.claude/repos/skills-repo/skills/
```

The UserPromptSubmit hook runs `git pull` on session start (24-hour cache). Every team member gets the latest skills automatically.

When someone creates or improves a skill, they push to the central repo. Next session, every teammate has the update.

## Writing Good Descriptions

The description field is what makes auto-invocation work. Write it for **intent matching**, not documentation:

### Good descriptions

```yaml
# Specific actions the user might ask for
description: >
  Query tables, explore schemas, check data,
  run volume analysis using BigQuery

# Clear trigger phrases
description: >
  Build and deploy AI agents using Google
  Agent Development Kit with Vertex AI on GCP

# Domain-specific terminology
description: >
  Scan and fix dependency vulnerabilities
  using Snyk security scanner
```

### Weak descriptions

```yaml
# Too vague — matches everything
description: Help with data tasks

# Too implementation-focused — users don't think this way
description: Executes SQL via the BigQuery MCP server tool

# Too narrow — misses common phrasings
description: Run SELECT queries on BigQuery
```

The routing table instruction says: *"If the user's intent matches a description, auto-invoke the skill."* Write descriptions that match how users naturally phrase requests.

---

*For the full skill library example, see [examples/skills-routing.md](../examples/skills-routing.md). For creating the routing table generator, see [scripts/generate_skill_routing.py](../scripts/generate_skill_routing.py).*
