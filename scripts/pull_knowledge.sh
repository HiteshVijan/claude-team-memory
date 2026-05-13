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
CONFIG_FILE="$CLAUDE_DIR/wiki-pages.json"
CACHE_TTL_WIKI=1800      # 30 minutes
CACHE_TTL_SKILLS=86400   # 24 hours

SKILLS_ONLY=false
[[ "${1:-}" == "--skills-only" ]] && SKILLS_ONLY=true

PYTHON3=$(command -v python3 || true)
[ -z "$PYTHON3" ] && echo "python3 required" && exit 1

mkdir -p "$WIKI_CACHE"

# ── Helper: check cache freshness ───────────────────────────
is_fresh() {
    local file="$1" ttl="$2"
    [ -f "$file" ] && {
        local age=$(( $(date +%s) - $(stat -f%m "$file" 2>/dev/null || stat -c%Y "$file" 2>/dev/null || echo 0) ))
        [ "$age" -lt "$ttl" ]
    }
}

# ════════════════════════════════════════════════════════════
# SECTION 1: Wiki Knowledge Pull
# ════════════════════════════════════════════════════════════

if ! $SKILLS_ONLY; then

    # Check cache freshness
    if is_fresh "$KNOWLEDGE_FILE" "$CACHE_TTL_WIKI"; then
        echo "[context-memory] Wiki knowledge is fresh (< 30 min), skipping pull"
    else
        echo "[context-memory] Pulling team knowledge from wiki..."

        # Load wiki credentials
        WIKI_ENV="$HOME/.config/confluence/.env"
        if [ -f "$WIKI_ENV" ]; then
            # shellcheck disable=SC1090
            source "$WIKI_ENV"
            export CONFLUENCE_USERNAME CONFLUENCE_API_TOKEN
        else
            echo "[context-memory] No wiki credentials at $WIKI_ENV — skipping wiki pull"
            echo "[context-memory] Set up credentials: see docs/tutorial.md"
        fi

        if [ -n "${CONFLUENCE_USERNAME:-}" ] && [ -n "${CONFLUENCE_API_TOKEN:-}" ] && [ -f "$CONFIG_FILE" ]; then
            # Read page IDs from config
            SHARED_PAGE_ID=$("$PYTHON3" -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('_meta',{}).get('shared_page_id',''))" 2>/dev/null || echo "")
            DEPMAP_PAGE_ID=$("$PYTHON3" -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('_meta',{}).get('dependency_map_page_id',''))" 2>/dev/null || echo "")
            WIKI_BASE=$("$PYTHON3" -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('_meta',{}).get('wiki_base_url',''))" 2>/dev/null || echo "")

            # Pull each page and convert to markdown
            pull_page() {
                local page_id="$1" output_file="$2" label="$3"
                if [ -n "$page_id" ] && [ -n "$WIKI_BASE" ]; then
                    echo "[context-memory] Pulling $label (page $page_id)..."
                    local response
                    response=$(curl -sf -u "$CONFLUENCE_USERNAME:$CONFLUENCE_API_TOKEN" \
                        "$WIKI_BASE/wiki/rest/api/content/$page_id?expand=body.storage" 2>/dev/null || echo "")

                    if [ -n "$response" ]; then
                        # Write response to temp file to avoid shell injection
                        local tmpfile
                        tmpfile=$(mktemp)
                        echo "$response" > "$tmpfile"

                        # Extract body and convert HTML to markdown
                        "$PYTHON3" << PYEOF > "$output_file"
import json, re, html, sys

with open('$tmpfile', 'r') as f:
    data = json.load(f)

body = data.get('body', {}).get('storage', {}).get('value', '')

# HTML to markdown conversion
body = re.sub(r'<h1[^>]*>(.*?)</h1>', r'# \1', body, flags=re.DOTALL)
body = re.sub(r'<h2[^>]*>(.*?)</h2>', r'## \1', body, flags=re.DOTALL)
body = re.sub(r'<h3[^>]*>(.*?)</h3>', r'### \1', body, flags=re.DOTALL)
body = re.sub(r'<strong>(.*?)</strong>', r'**\1**', body, flags=re.DOTALL)
body = re.sub(r'<em>(.*?)</em>', r'*\1*', body, flags=re.DOTALL)

# Table conversion
def convert_tables(text):
    import re as _re
    def table_to_md(match):
        table_html = match.group(0)
        rows = _re.findall(r'<tr[^>]*>(.*?)</tr>', table_html, _re.DOTALL)
        md_rows = []
        for i, row in enumerate(rows):
            cells = _re.findall(r'<t[hd][^>]*>(.*?)</t[hd]>', row, _re.DOTALL)
            cells = [_re.sub(r'<[^>]+>', '', c).strip() for c in cells]
            md_rows.append('| ' + ' | '.join(cells) + ' |')
            if i == 0:
                md_rows.append('|' + '|'.join(['---'] * len(cells)) + '|')
        return '\n'.join(md_rows)
    return _re.sub(r'<table[^>]*>.*?</table>', table_to_md, text, flags=_re.DOTALL)

body = convert_tables(body)
body = re.sub(r'<li>(.*?)</li>', r'- \1', body, flags=re.DOTALL)
body = re.sub(r'<br\s*/?>', '\n', body)
body = re.sub(r'<p>(.*?)</p>', r'\1\n', body, flags=re.DOTALL)
body = re.sub(r'<[^>]+>', '', body)
body = html.unescape(body)

title = data.get('title', 'Untitled')
print(f"# {title}\n")
print(body.strip())
PYEOF
                        rm -f "$tmpfile"
                        echo "[context-memory] ✓ $label cached"
                    else
                        echo "[context-memory] ✗ Failed to pull $label"
                    fi
                fi
            }

            # Pull shared standards
            [ -n "$SHARED_PAGE_ID" ] && pull_page "$SHARED_PAGE_ID" "$WIKI_CACHE/shared.md" "Shared Standards"

            # Pull dependency map
            [ -n "$DEPMAP_PAGE_ID" ] && pull_page "$DEPMAP_PAGE_ID" "$WIKI_CACHE/depmap.md" "Dependency Map"

            # Pull domain pages
            DOMAIN_PAGES=$("$PYTHON3" -c "
import json
c = json.load(open('$CONFIG_FILE'))
for k, v in c.get('_meta', {}).get('domain_pages', {}).items():
    print(f'{k}:{v}')
" 2>/dev/null || echo "")

            while IFS=: read -r domain_name domain_page_id; do
                [ -n "$domain_name" ] && pull_page "$domain_page_id" "$WIKI_CACHE/domain_${domain_name}.md" "Domain: $domain_name"
            done <<< "$DOMAIN_PAGES"

            # Pull current repo module detail
            CURRENT_REPO=$(basename "$(pwd)")
            REPO_PAGE_ID=$("$PYTHON3" -c "
import json
c = json.load(open('$CONFIG_FILE'))
print(c.get('repos', {}).get('$CURRENT_REPO', {}).get('page_id', ''))
" 2>/dev/null || echo "")

            [ -n "$REPO_PAGE_ID" ] && pull_page "$REPO_PAGE_ID" "$WIKI_CACHE/${CURRENT_REPO}.md" "Repo: $CURRENT_REPO"

            # Assemble team_knowledge.md from cached pages
            echo "[context-memory] Assembling team_knowledge.md..."
            {
                echo "# Team Knowledge Base (Shared)"
                echo ""
                [ -f "$WIKI_CACHE/shared.md" ] && cat "$WIKI_CACHE/shared.md" && echo ""
                [ -f "$WIKI_CACHE/depmap.md" ] && cat "$WIKI_CACHE/depmap.md" && echo ""

                # Include domain pages
                for f in "$WIKI_CACHE"/domain_*.md; do
                    [ -f "$f" ] && cat "$f" && echo ""
                done

                # On-demand detail pointers
                echo "## On-Demand Detail Sections"
                echo "Load these with the Read tool when a task needs them."
                echo ""
                for f in "$WIKI_CACHE"/*.md; do
                    fname=$(basename "$f" .md)
                    case "$fname" in
                        shared|depmap|domain_*) continue ;;
                        *) echo "- **Module: $fname** — Read \`$f\`" ;;
                    esac
                done
            } > "$KNOWLEDGE_FILE"

            echo "[context-memory] ✓ team_knowledge.md assembled"
        fi
    fi
fi

# ════════════════════════════════════════════════════════════
# SECTION 2: Skills Repo Pull + Routing Table Generation
# ════════════════════════════════════════════════════════════

NEED_SKILLS_PULL=false

# Check if skills repo needs a pull
SKILLS_REPO_DIR="$REPOS_DIR/skills"
SKILLS_PULL_MARKER="$CACHE_DIR/.skills_last_pull"

if [ -d "$SKILLS_REPO_DIR/.git" ]; then
    if ! is_fresh "$SKILLS_PULL_MARKER" "$CACHE_TTL_SKILLS"; then
        echo "[context-memory] Pulling skills repo..."
        (cd "$SKILLS_REPO_DIR" && git pull --quiet 2>/dev/null) && touch "$SKILLS_PULL_MARKER"
        NEED_SKILLS_PULL=true
    fi
fi

# Generate skill routing table
if [ -d "$SKILLS_DIR" ] && { $NEED_SKILLS_PULL || [ ! -f "$SKILLS_ROUTING_FILE" ]; }; then
    echo "[context-memory] Generating skill routing table..."

    "$PYTHON3" << 'PYEOF' 2>/dev/null
import os, re, glob

SKILLS_DIR = os.path.expanduser("~/.claude/skills")
OUTPUT = os.path.expanduser("~/.claude/cache/skills_routing.md")
os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)

# ── Category mapping ─────────────────────────────────────
# Map skill names to categories. Skills not in any list → "Other"
# Customize this dict for your team's skill library.
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

# Build reverse lookup: skill_name → category
skill_to_cat = {}
for cat, skills in CATEGORIES.items():
    for s in skills:
        skill_to_cat[s] = cat


def parse_yaml_value(lines, start_idx):
    """Parse a YAML value that might be multiline (>, >-, |)."""
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
    """Parse SKILL.md frontmatter to extract name and description."""
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


# ── Discover all skills ──────────────────────────────────
skills = {}

for skill_md in sorted(glob.glob(os.path.join(SKILLS_DIR, "*/SKILL.md"))):
    dir_name = os.path.basename(os.path.dirname(skill_md))
    name, description = parse_skill_md(skill_md)

    if not name:
        name = dir_name
    if not description:
        description = f"(no description — add one to {dir_name}/SKILL.md)"

    skills[name] = description

# ── Group by category ────────────────────────────────────
categorized = {}
for name, desc in sorted(skills.items()):
    cat = skill_to_cat.get(name, "Other")
    categorized.setdefault(cat, []).append((name, desc))

# ── Write routing table ─────────────────────────────────
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
