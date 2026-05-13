#!/usr/bin/env bash
# Context Memory — Quick Install
# One-liner: bash <(curl -fsSL https://raw.githubusercontent.com/HiteshVijan/claude-team-memory/main/scripts/quick-install.sh)
#
# What this does:
#   1. Clones the repo to ~/.claude/repos/claude-team-memory
#   2. Creates directory structure (~/.claude/cache, rules, scripts)
#   3. Installs the UserPromptSubmit hook (pull_knowledge.sh on every session start)
#   4. Generates a starter CLAUDE.md (preserves existing personal section)
#   5. Copies example files as starting points

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}✓${NC} $1"; }
warn()  { echo -e "${YELLOW}!${NC} $1"; }
step()  { echo -e "${CYAN}→${NC} $1"; }

CLAUDE_DIR="$HOME/.claude"
REPO_DIR="$CLAUDE_DIR/repos/claude-team-memory"
REPO_URL="https://github.com/HiteshVijan/claude-team-memory.git"

echo ""
echo "╔═══════════════════════════════════════════╗"
echo "║   Context Memory for Claude Code          ║"
echo "║   Persistent team knowledge, auto-loaded  ║"
echo "╚═══════════════════════════════════════════╝"
echo ""

# ── Step 1: Clone or update repo ──────────────────────────
step "Checking for existing installation..."
if [ -d "$REPO_DIR/.git" ]; then
    warn "Existing installation found — pulling latest"
    (cd "$REPO_DIR" && git pull --quiet 2>/dev/null) || true
else
    step "Cloning Context Memory..."
    mkdir -p "$(dirname "$REPO_DIR")"
    git clone --quiet "$REPO_URL" "$REPO_DIR"
fi
info "Repo ready at $REPO_DIR"

# ── Step 2: Create directory structure ────────────────────
step "Creating directory structure..."
mkdir -p "$CLAUDE_DIR/cache/wiki"
mkdir -p "$CLAUDE_DIR/rules"
mkdir -p "$CLAUDE_DIR/scripts"
info "Directories created"

# ── Step 3: Install pull script ───────────────────────────
step "Installing knowledge sync script..."
cp "$REPO_DIR/scripts/pull_knowledge.sh" "$CLAUDE_DIR/scripts/"
chmod +x "$CLAUDE_DIR/scripts/pull_knowledge.sh"
info "pull_knowledge.sh installed"

# ── Step 4: Install hook ──────────────────────────────────
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
step "Configuring session hook..."

if [ -f "$SETTINGS_FILE" ]; then
    if grep -q "pull_knowledge" "$SETTINGS_FILE" 2>/dev/null; then
        info "Hook already configured — skipping"
    else
        warn "settings.json exists but no hook found"
        warn "Add this to your settings.json under hooks.UserPromptSubmit:"
        echo '    {"type": "command", "command": "bash ~/.claude/scripts/pull_knowledge.sh 2>/dev/null || true"}'
    fi
else
    cat > "$SETTINGS_FILE" << 'EOF'
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
EOF
    info "Session hook installed"
fi

# ── Step 5: Generate starter CLAUDE.md ────────────────────
step "Setting up CLAUDE.md..."

if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
    warn "CLAUDE.md already exists — not overwriting"
    warn "See $REPO_DIR/examples/CLAUDE.md for the recommended template"
else
    cat > "$CLAUDE_DIR/CLAUDE.md" << 'CLAUDE_EOF'
# Claude Code — Global Instructions

## Who I Work With
- Name: YOUR_NAME
- Role: YOUR_ROLE, YOUR_TEAM team
- Email: YOUR_EMAIL

## How to Work
- Check the skill routing table BEFORE every response. If the user's intent matches, auto-invoke the skill
- Trust user's domain knowledge — verify with data/docs, not exhaustive code tracing
- When a question has multiple interpretations, ask before searching
- Keep responses concise

## Team Standards (shared across all teammates)
@~/.claude/rules/team-standards.md

## Skill Routing (auto-generated from SKILL.md files — always up-to-date)
@~/.claude/cache/skills_routing.md

## Team Knowledge (auto-synced from wiki — the single source of truth)
@~/.claude/team_knowledge.md

<!-- BEGIN PERSONAL — everything below this line is yours, never overwritten -->
## Personal

CLAUDE_EOF
    info "Starter CLAUDE.md created — edit it with your details"
fi

# ── Step 6: Install rules + seed cache files ─────────────
step "Installing rules and starter files..."

if [ -d "$REPO_DIR/framework/rules" ]; then
    mkdir -p "$CLAUDE_DIR/rules"
    cp "$REPO_DIR/framework/rules/"*.md "$CLAUDE_DIR/rules/" 2>/dev/null || true
    info "Team standards template installed to ~/.claude/rules/"
fi

mkdir -p "$CLAUDE_DIR/cache"
if [ ! -f "$CLAUDE_DIR/cache/skills_routing.md" ]; then
    cat > "$CLAUDE_DIR/cache/skills_routing.md" << 'SR_EOF'
## Skill Routing Table
No skills configured yet. To add skills:
1. Create skill directories under ~/.claude/skills/ with SKILL.md files
2. Run: bash ~/.claude/scripts/pull_knowledge.sh
The routing table will be auto-generated from SKILL.md YAML frontmatter.
SR_EOF
    info "Starter skills_routing.md created"
fi

# ── Step 7: Copy example files + create starters ─────────
step "Setting up starter files..."

if [ ! -f "$CLAUDE_DIR/wiki-pages.json" ]; then
    cp "$REPO_DIR/examples/wiki-pages.json" "$CLAUDE_DIR/wiki-pages.json"
    info "wiki-pages.json copied — edit with your page IDs"
else
    warn "wiki-pages.json already exists — skipping"
fi

if [ ! -f "$CLAUDE_DIR/team_knowledge.md" ]; then
    cat > "$CLAUDE_DIR/team_knowledge.md" << 'TK_EOF'
# Team Knowledge Base (Shared)

This file is auto-populated when wiki sync is configured.
To set up wiki sync, see: https://github.com/HiteshVijan/claude-team-memory/blob/main/docs/tutorial.md

Until then, you can add team knowledge directly here.

## Team Standards
<!-- Add your team's standards, conventions, and guardrails -->

## Dependency Map
<!-- Add your service registry, workflow dependencies, and data lineage -->
TK_EOF
    info "Starter team_knowledge.md created"
fi

# ── Done ──────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════"
echo ""
info "Context Memory installed!"
echo ""
echo "  Next steps:"
echo "  1. Edit ~/.claude/CLAUDE.md — fill in your name and role"
echo "  2. Set up Confluence credentials:"
echo "       mkdir -p ~/.config/confluence"
echo "       cat > ~/.config/confluence/.env << 'ENVEOF'"
echo "       CONFLUENCE_BASE_URL=https://your-org.atlassian.net"
echo "       CONFLUENCE_USERNAME=you@company.com"
echo "       CONFLUENCE_API_TOKEN=your-api-token"
echo "       ENVEOF"
echo ""
echo "  3. Edit ~/.claude/wiki-pages.json with your page IDs"
echo "  4. Start a new Claude Code session — knowledge loads automatically"
echo ""
echo "  Docs: $REPO_DIR/docs/"
echo "  Examples: $REPO_DIR/examples/"
echo ""
