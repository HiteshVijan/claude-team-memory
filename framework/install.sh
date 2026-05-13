#!/usr/bin/env bash
# Context Memory — One-Command Installer
# Installs the framework, team pack, and hooks for Claude Code.
#
# Usage:
#   bash install.sh                    # Interactive (prompts for team pack)
#   bash install.sh --team-pack myteam # Non-interactive

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CLAUDE_DIR="$HOME/.claude"
CACHE_DIR="$CLAUDE_DIR/cache"
RULES_DIR="$CLAUDE_DIR/rules"
SCRIPTS_DIR="$CLAUDE_DIR/scripts"
SKILLS_DIR="$CLAUDE_DIR/skills"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ── Parse args ──────────────────────────────────────────────
TEAM_PACK=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --team-pack) TEAM_PACK="$2"; shift 2 ;;
        *) error "Unknown option: $1" ;;
    esac
done

# ── Discover available team packs ───────────────────────────
PACKS_DIR="$REPO_ROOT/team-packs"
if [ -d "$PACKS_DIR" ] && [ -z "$TEAM_PACK" ]; then
    echo ""
    echo "Available team packs:"
    for pack in "$PACKS_DIR"/*/; do
        [ -d "$pack" ] || continue
        pack_name=$(basename "$pack")
        [ "$pack_name" = "generic" ] && continue
        echo "  - $pack_name"
    done
    echo ""
    read -rp "Which team pack? (or 'generic' for base only): " TEAM_PACK
elif [ -z "$TEAM_PACK" ]; then
    TEAM_PACK="generic"
fi

PACK_DIR="$PACKS_DIR/$TEAM_PACK"
if [ "$TEAM_PACK" != "generic" ] && [ ! -d "$PACK_DIR" ]; then
    warn "Team pack '$TEAM_PACK' not found — using generic base install"
    TEAM_PACK="generic"
fi

# ── Load team environment ──────────────────────────────────
if [ "$TEAM_PACK" != "generic" ] && [ -f "$PACK_DIR/team.env" ]; then
    info "Loading team environment from $TEAM_PACK/team.env"
    # shellcheck disable=SC1091
    source "$PACK_DIR/team.env"
fi

# ── Create directory structure ─────────────────────────────
info "Creating directory structure..."
mkdir -p "$CACHE_DIR/wiki" "$RULES_DIR" "$SCRIPTS_DIR"

# ── Install base CLAUDE.md from template ───────────────────
info "Installing CLAUDE.md..."
BASE_TMPL="$REPO_ROOT/framework/claude-base.md.tmpl"
TEAM_TMPL=""
[ "$TEAM_PACK" != "generic" ] && [ -f "$PACK_DIR/claude-team.md.tmpl" ] && TEAM_TMPL="$PACK_DIR/claude-team.md.tmpl"

if [ -f "$BASE_TMPL" ]; then
    # Render template — replace {{VAR}} with env values
    RENDERED=$(cat "$BASE_TMPL")

    # Replace known template variables
    RENDERED="${RENDERED//\{\{USER_NAME\}\}/${USER_NAME:-Your Name}}"
    RENDERED="${RENDERED//\{\{USER_ROLE\}\}/${USER_ROLE:-Engineer}}"
    RENDERED="${RENDERED//\{\{USER_EMAIL\}\}/${USER_EMAIL:-you@company.com}}"
    RENDERED="${RENDERED//\{\{USER_AID\}\}/${USER_AID:-your-id}}"
    RENDERED="${RENDERED//\{\{TEAM_DISPLAY_NAME\}\}/${TEAM_DISPLAY_NAME:-Your Team}}"
    RENDERED="${RENDERED//\{\{JIRA_PROJECT_KEY\}\}/${JIRA_PROJECT_KEY:-PROJ}}"
    RENDERED="${RENDERED//\{\{JIRA_BASE_URL\}\}/${JIRA_BASE_URL:-https://your-org.atlassian.net}}"
    RENDERED="${RENDERED//\{\{JIRA_CLOUD_ID\}\}/${JIRA_CLOUD_ID:-your-cloud-id}}"

    # Append team-specific section if it exists
    if [ -n "$TEAM_TMPL" ]; then
        TEAM_RENDERED=$(cat "$TEAM_TMPL")
        TEAM_RENDERED="${TEAM_RENDERED//\{\{JIRA_PROJECT_KEY\}\}/${JIRA_PROJECT_KEY:-PROJ}}"
        TEAM_RENDERED="${TEAM_RENDERED//\{\{JIRA_BASE_URL\}\}/${JIRA_BASE_URL:-https://your-org.atlassian.net}}"
        TEAM_RENDERED="${TEAM_RENDERED//\{\{JIRA_CLOUD_ID\}\}/${JIRA_CLOUD_ID:-your-cloud-id}}"
        RENDERED="$RENDERED"$'\n\n'"$TEAM_RENDERED"
    fi

    # Write CLAUDE.md — preserve personal section if it exists
    if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
        PERSONAL_MARKER="<!-- BEGIN PERSONAL"
        if grep -q "$PERSONAL_MARKER" "$CLAUDE_DIR/CLAUDE.md"; then
            PERSONAL_SECTION=$(sed -n "/$PERSONAL_MARKER/,\$p" "$CLAUDE_DIR/CLAUDE.md")
            RENDERED="$RENDERED"$'\n\n'"$PERSONAL_SECTION"
        fi
        warn "Existing CLAUDE.md backed up to CLAUDE.md.bak"
        cp "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md.bak"
    fi

    echo "$RENDERED" > "$CLAUDE_DIR/CLAUDE.md"
    info "CLAUDE.md installed"
fi

# ── Install rules ──────────────────────────────────────────
info "Installing rules..."

# Base rules from framework
if [ -d "$REPO_ROOT/framework/rules" ]; then
    cp "$REPO_ROOT/framework/rules/"*.md "$RULES_DIR/" 2>/dev/null || true
fi

# Team-specific rules
if [ "$TEAM_PACK" != "generic" ] && [ -d "$PACK_DIR/rules" ]; then
    cp "$PACK_DIR/rules/"*.md "$RULES_DIR/" 2>/dev/null || true
fi

info "Rules installed to $RULES_DIR/"

# ── Install scripts ────────────────────────────────────────
info "Installing scripts..."
cp "$REPO_ROOT/scripts/pull_knowledge.sh" "$SCRIPTS_DIR/"
chmod +x "$SCRIPTS_DIR/pull_knowledge.sh"

# ── Create starter files if missing ────────────────────────
if [ ! -f "$CLAUDE_DIR/team_knowledge.md" ]; then
    cat > "$CLAUDE_DIR/team_knowledge.md" << 'STARTER_EOF'
# Team Knowledge Base (Shared)

This file is auto-populated when wiki sync is configured.
To set up wiki sync, see: https://github.com/HiteshVijan/claude-team-memory/blob/main/docs/tutorial.md

Until then, you can add team knowledge directly here.

## Team Standards
<!-- Add your team's standards, conventions, and guardrails -->

## Dependency Map
<!-- Add your service registry, workflow dependencies, and data lineage -->
STARTER_EOF
    info "Starter team_knowledge.md created"
fi

if [ ! -f "$CLAUDE_DIR/wiki-pages.json" ]; then
    cp "$REPO_ROOT/examples/wiki-pages.json" "$CLAUDE_DIR/wiki-pages.json" 2>/dev/null || true
    info "wiki-pages.json copied — edit with your page IDs"
fi

# ── Install Claude Code hooks ──────────────────────────────
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
if [ ! -f "$SETTINGS_FILE" ]; then
    info "Installing Claude Code hooks..."
    cat > "$SETTINGS_FILE" << 'SETTINGS_EOF'
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
SETTINGS_EOF
    info "Hooks installed at $SETTINGS_FILE"
else
    warn "settings.json already exists — verify UserPromptSubmit hook is configured"
fi

# ── Seed skills routing (so @-import never fails) ─────────
if [ -d "$SKILLS_DIR" ]; then
    info "Generating initial skill routing table..."
    bash "$SCRIPTS_DIR/pull_knowledge.sh" --skills-only 2>/dev/null || true
elif [ ! -f "$CACHE_DIR/skills_routing.md" ]; then
    cat > "$CACHE_DIR/skills_routing.md" << 'SR_EOF'
## Skill Routing Table
No skills configured yet. To add skills:
1. Create skill directories under ~/.claude/skills/ with SKILL.md files
2. Run: bash ~/.claude/scripts/pull_knowledge.sh
The routing table will be auto-generated from SKILL.md YAML frontmatter.
SR_EOF
    info "Starter skills_routing.md created"
fi

# ── Summary ────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════"
echo "  Context Memory installed successfully!"
echo "═══════════════════════════════════════════════════"
echo ""
echo "  Team pack:    $TEAM_PACK"
echo "  CLAUDE.md:    $CLAUDE_DIR/CLAUDE.md"
echo "  Rules:        $RULES_DIR/"
echo "  Scripts:      $SCRIPTS_DIR/"
echo "  Cache:        $CACHE_DIR/"
echo ""
echo "  Next steps:"
echo "  1. Edit ~/.claude/CLAUDE.md — fill in your name and role"
echo "  2. Set up wiki credentials:"
echo "       mkdir -p ~/.config/confluence"
echo "       # Add CONFLUENCE_USERNAME and CONFLUENCE_API_TOKEN to ~/.config/confluence/.env"
echo "  3. Edit ~/.claude/wiki-pages.json with your page IDs"
echo "  4. Start a Claude Code session — knowledge loads automatically"
echo ""
