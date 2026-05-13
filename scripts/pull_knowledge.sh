#!/usr/bin/env bash
# Context Memory — Knowledge Pull Script
# Syncs team knowledge from wiki + generates skill routing table.
# Runs automatically via UserPromptSubmit hook on every Claude Code session start.
#
# Usage:
#   bash pull_knowledge.sh              # Full sync (wiki + skills)
#   bash pull_knowledge.sh --skills-only # Only regenerate skill routing

set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
CACHE_DIR="$CLAUDE_DIR/cache"
WIKI_CACHE="$CACHE_DIR/wiki"
KNOWLEDGE_FILE="$CLAUDE_DIR/team_knowledge.md"
SKILLS_ROUTING_FILE="$CACHE_DIR/skills_routing.md"
SKILLS_DIR="$CLAUDE_DIR/skills"
REPOS_DIR="$CLAUDE_DIR/repos"
CONFIG_FILE="$CLAUDE_DIR/knowledge-pages.json"
CACHE_TTL_WIKI=1800      # 30 minutes
CACHE_TTL_SKILLS=86400   # 24 hours

SKILLS_ONLY=false
[[ "${1:-}" == "--skills-only" ]] && SKILLS_ONLY=true

PYTHON3=$(command -v python3 || true)
[ -z "$PYTHON3" ] && echo "python3 required" && exit 1

mkdir -p "$WIKI_CACHE"

# Resolve adapter directory (works whether running from repo or ~/.claude/scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADAPTERS_DIR=""
for candidate in "$SCRIPT_DIR/../adapters" "$CLAUDE_DIR/repos/claude-team-memory/adapters"; do
    if [ -d "$candidate/wikis" ]; then
        ADAPTERS_DIR="$(cd "$candidate" && pwd)"
        break
    fi
done

# ── Helper: check cache freshness ───────────────────────────
is_fresh() {
    local file="$1" ttl="$2"
    [ -f "$file" ] && {
        local age=$(( $(date +%s) - $(stat -f%m "$file" 2>/dev/null || stat -c%Y "$file" 2>/dev/null || echo 0) ))
        [ "$age" -lt "$ttl" ]
    }
}

# ── Helper: assemble team_knowledge.md from cached pages ────
assemble_knowledge() {
    echo "[context-memory] Assembling team_knowledge.md..."
    {
        echo "# Team Knowledge Base (Shared)"
        echo ""
        [ -f "$WIKI_CACHE/shared.md" ] && cat "$WIKI_CACHE/shared.md" && echo ""
        [ -f "$WIKI_CACHE/depmap.md" ] && cat "$WIKI_CACHE/depmap.md" && echo ""

        echo "## On-Demand Detail Sections"
        echo "Load these with the Read tool when a task needs them."
        echo ""
        for f in "$WIKI_CACHE"/*.md; do
            [ -f "$f" ] || continue
            fname=$(basename "$f" .md)
            case "$fname" in
                shared|depmap) continue ;;
                domain_*) echo "- **${fname#domain_}** — Read \`$f\`" ;;
                *) echo "- **Module: $fname** — Read \`$f\`" ;;
            esac
        done
    } > "$KNOWLEDGE_FILE"

    echo "[context-memory] ✓ team_knowledge.md assembled"
}

# Export shared vars for adapters
export WIKI_CACHE KNOWLEDGE_FILE CONFIG_FILE PYTHON3

# ════════════════════════════════════════════════════════════
# SECTION 1: Wiki Knowledge Pull (adapter-dispatched)
# ════════════════════════════════════════════════════════════

if ! $SKILLS_ONLY; then

    if is_fresh "$KNOWLEDGE_FILE" "$CACHE_TTL_WIKI"; then
        echo "[context-memory] Wiki knowledge is fresh (< 30 min), skipping pull"
    else
        echo "[context-memory] Pulling team knowledge from wiki..."

        WIKI_PROVIDER="confluence"
        if [ -f "$CONFIG_FILE" ]; then
            WIKI_PROVIDER=$("$PYTHON3" -c "import json; print(json.load(open('$CONFIG_FILE')).get('_meta',{}).get('wiki_provider','confluence'))" 2>/dev/null || echo "confluence")
        fi

        ADAPTER_SCRIPT=""
        if [ -n "$ADAPTERS_DIR" ]; then
            ADAPTER_SCRIPT="$ADAPTERS_DIR/wikis/$WIKI_PROVIDER/pull.sh"
            [ ! -f "$ADAPTER_SCRIPT" ] && ADAPTER_SCRIPT="$ADAPTERS_DIR/wikis/$WIKI_PROVIDER/pull.py"
        fi

        if [ -n "$ADAPTER_SCRIPT" ] && [ -f "$ADAPTER_SCRIPT" ]; then
            case "$ADAPTER_SCRIPT" in
                *.sh) source "$ADAPTER_SCRIPT" && run_pull ;;
                *.py) "$PYTHON3" "$ADAPTER_SCRIPT" && assemble_knowledge ;;
            esac
        else
            echo "[context-memory] No adapter found for wiki_provider=$WIKI_PROVIDER"
            echo "[context-memory] Available adapters: $(ls "$ADAPTERS_DIR/wikis/" 2>/dev/null || echo 'none')"
        fi
    fi
fi

# ════════════════════════════════════════════════════════════
# SECTION 2: Skills Repo Pull + Routing Table Generation
# ════════════════════════════════════════════════════════════

NEED_SKILLS_PULL=false

SKILLS_REPO_DIR="$REPOS_DIR/skills"
SKILLS_PULL_MARKER="$CACHE_DIR/.skills_last_pull"

if [ -d "$SKILLS_REPO_DIR/.git" ]; then
    if ! is_fresh "$SKILLS_PULL_MARKER" "$CACHE_TTL_SKILLS"; then
        echo "[context-memory] Pulling skills repo..."
        (cd "$SKILLS_REPO_DIR" && git pull --quiet 2>/dev/null) && touch "$SKILLS_PULL_MARKER"
        NEED_SKILLS_PULL=true
    fi
fi

if [ -d "$SKILLS_DIR" ] && { $NEED_SKILLS_PULL || [ ! -f "$SKILLS_ROUTING_FILE" ]; }; then
    echo "[context-memory] Generating skill routing table..."

    "$PYTHON3" << 'PYEOF' 2>/dev/null
import os, re, glob

SKILLS_DIR = os.path.expanduser("~/.claude/skills")
OUTPUT = os.path.expanduser("~/.claude/cache/skills_routing.md")
os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)

CATEGORIES = {
    "AI & Agents": [
        "adk-agent", "agent-dev-lifecycle", "datascience-agent",
        "dispatching-parallel-agents", "genai-accelerators",
        "google-adk-patterns", "google-adk-python", "manage-agent-engine",
        "rag", "subagent-driven-development",
    ],
    "Data Engineering": [
        "bigquery", "data-pipeline", "data-science", "gcs",
    ],
    "Architecture & Design": [
        "arb-review", "arch-gate", "architecture-design",
        "architecture-documentation", "estimation", "requirements-elaboration",
    ],
    "CI/CD & Deployment": [
        "app-dev-lifecycle", "cap-deployment", "create-github-repo",
        "deploy-shared-flow", "deploy-gke", "gha-ci-node",
        "gha-ci-python", "docker-publish", "terraform",
    ],
    "GCP & Infrastructure": [
        "cloud-cost", "gcp-setup", "gke-cluster-creation",
        "gke-dev-deployment-troubleshoot", "gke-pvc-data-loader",
        "kubectl-setup", "secrets-management",
    ],
    "Code Quality": [
        "test-driven-development", "systematic-debugging",
        "requesting-code-review", "receiving-code-review",
        "e2e-verify", "changelog-generator",
        "verification-before-completion",
    ],
    "Atlassian & Ticketing": [
        "jira", "confluence", "ticketing-workflow", "scan-jira-tickets",
    ],
    "Frontend": [
        "react-app", "frontend-components",
    ],
    "Security": [
        "security-guardrails", "sentry", "snyk-autofix",
        "security-scanning",
    ],
    "Utilities": [
        "mermaid-rendering", "mcp-builder", "skill-creator",
        "dev-onboarding", "proxy-vpn-config", "socratic",
        "writing-skills",
    ],
}

skill_to_cat = {}
for cat, skills in CATEGORIES.items():
    for s in skills:
        skill_to_cat[s] = cat


def parse_yaml_value(lines, start_idx):
    line = lines[start_idx]
    match = re.match(r'^(\w+):\s*(.*)', line)
    if not match:
        return ""
    value = match.group(2).strip()

    if value and value not in ('>', '>-', '|', '|-'):
        return value.strip('"').strip("'")

    is_folded = value in ('>', '>-')
    is_literal = value in ('|', '|-')

    if not (is_folded or is_literal):
        return value.strip('"').strip("'")

    parts = []
    indent = None
    for i in range(start_idx + 1, len(lines)):
        l = lines[i]
        if not l.strip() or l.startswith('---'):
            break
        stripped = l.lstrip()
        line_indent = len(l) - len(stripped)
        if indent is None:
            indent = line_indent
        if line_indent < indent:
            break
        parts.append(stripped)

    if is_folded:
        return ' '.join(parts)
    else:
        return '\n'.join(parts)


def parse_skill_md(filepath):
    try:
        with open(filepath, 'r') as f:
            content = f.read()
    except Exception:
        return None, None

    if not content.startswith('---'):
        return None, None

    end = content.find('---', 3)
    if end == -1:
        return None, None

    frontmatter = content[3:end].strip()
    lines = frontmatter.split('\n')

    name = None
    description = None

    for i, line in enumerate(lines):
        if line.startswith('name:'):
            name = parse_yaml_value(lines, i)
        elif line.startswith('description:'):
            description = parse_yaml_value(lines, i)

    return name, description


skills = {}

for skill_md in sorted(glob.glob(os.path.join(SKILLS_DIR, "*/SKILL.md"))):
    dir_name = os.path.basename(os.path.dirname(skill_md))
    name, description = parse_skill_md(skill_md)

    if not name:
        name = dir_name
    if not description:
        description = f"(no description — add one to {dir_name}/SKILL.md)"

    skills[name] = description

categorized = {}
for name, desc in sorted(skills.items()):
    cat = skill_to_cat.get(name, "Other")
    categorized.setdefault(cat, []).append((name, desc))

CATEGORY_ORDER = [
    "AI & Agents", "Data Engineering", "Architecture & Design",
    "CI/CD & Deployment", "GCP & Infrastructure", "Code Quality",
    "Atlassian & Ticketing", "Frontend", "Security", "Utilities", "Other",
]

with open(OUTPUT, 'w') as f:
    f.write("## Skill Routing Table (Auto-Generated)\n")
    f.write("Check this table before every response. If the user's intent matches a description, auto-invoke the skill.\n\n")

    for cat in CATEGORY_ORDER:
        if cat not in categorized:
            continue
        f.write(f"### {cat}\n")
        f.write("| Skill | When to invoke |\n")
        f.write("|-------|---------------|\n")
        for name, desc in categorized[cat]:
            if len(desc) > 120:
                desc = desc[:117] + "..."
            f.write(f"| `/{name}` | {desc} |\n")
        f.write("\n")

    for cat in sorted(categorized.keys()):
        if cat in CATEGORY_ORDER:
            continue
        f.write(f"### {cat}\n")
        f.write("| Skill | When to invoke |\n")
        f.write("|-------|---------------|\n")
        for name, desc in categorized[cat]:
            if len(desc) > 120:
                desc = desc[:117] + "..."
            f.write(f"| `/{name}` | {desc} |\n")
        f.write("\n")

count = len(skills)
print(f"[context-memory] ✓ Skill routing table generated: {count} skills")
PYEOF

fi

echo "[context-memory] Pull complete."
