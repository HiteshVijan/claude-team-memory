# Contributing to Context Memory

Thanks for your interest in contributing! Context Memory is an open-source framework that gives AI coding assistants persistent team knowledge. We welcome contributions of all kinds.

## Contribution Roadmap

| Area | What to build | Difficulty | Status |
|------|-------------|------------|--------|
| **Wiki: Notion** | `adapters/wikis/notion/` — pull + push via Notion API | Medium | [Issue #1](https://github.com/HiteshVijan/claude-team-memory/issues/1) |
| **Wiki: GitBook** | `adapters/wikis/gitbook/` — API or git-based sync | Easy | [Issue #2](https://github.com/HiteshVijan/claude-team-memory/issues/2) |
| **Wiki: SharePoint** | `adapters/wikis/sharepoint/` — Microsoft Graph API | Hard | [Issue #3](https://github.com/HiteshVijan/claude-team-memory/issues/3) |
| **Wiki: Git Markdown** | `adapters/wikis/git-markdown/` — plain git repo sync | Easy | [Issue #4](https://github.com/HiteshVijan/claude-team-memory/issues/4) |
| **Tool: Cursor** | `adapters/tools/cursor/` — inject into .cursorrules | Easy | [Issue #5](https://github.com/HiteshVijan/claude-team-memory/issues/5) |
| **Tool: GitHub Copilot** | `adapters/tools/github-copilot/` — inject into copilot-instructions.md | Easy | [Issue #6](https://github.com/HiteshVijan/claude-team-memory/issues/6) |
| **Tool: OpenAI Codex** | `adapters/tools/openai-codex/` — inject into AGENTS.md | Easy | [Issue #7](https://github.com/HiteshVijan/claude-team-memory/issues/7) |
| **Tool: Windsurf** | `adapters/tools/windsurf/` — inject into .windsurfrules | Easy | [Issue #8](https://github.com/HiteshVijan/claude-team-memory/issues/8) |
| **Tool: Aider** | `adapters/tools/aider/` — inject into conventions file | Easy | [Issue #9](https://github.com/HiteshVijan/claude-team-memory/issues/9) |
| **Tool: Continue.dev** | `adapters/tools/continue/` — inject into config.json | Medium | [Issue #10](https://github.com/HiteshVijan/claude-team-memory/issues/10) |
| **CLI tool** | `ctm` command — pull, push, status, init | Medium | Planned |
| **VS Code extension** | Workspace context injection + push UI | Hard | Planned |
| **GitHub Action** | PR knowledge injection + drift detection | Medium | Planned |
| **Benchmarks** | Context window efficiency measurement suite | Medium | Planned |
| **Team Packs** | Templates for frontend, ML, SRE, mobile teams | Easy | One example exists |

See the linked GitHub issues for details on each area. Use `adapters/wikis/confluence/` as the reference implementation.

## How to Build a Wiki Adapter

Reference implementation: `adapters/wikis/confluence/pull.sh`

A wiki adapter has 4 files:

```
adapters/wikis/your-wiki/
  pull.sh (or pull.py)     # Fetch pages, convert to markdown, write to cache
  push.sh (or push.py)     # Write learnings back to wiki pages
  README.md                # Setup instructions
  credentials.env.example  # Example credentials file
```

### The `run_pull()` contract

Your pull script is **sourced** by `scripts/pull_knowledge.sh`. It must define a `run_pull()` function that:

1. Reads credentials from `~/.config/{your-wiki}/.env`
2. Reads page IDs from `$CONFIG_FILE` (knowledge-pages.json)
3. Fetches each configured page via your wiki's API
4. Converts the response to Markdown
5. Writes output files to `$WIKI_CACHE/`:
   - `shared.md` — Tier 1 (team standards)
   - `depmap.md` — Tier 2 (dependency map)
   - `domain_{name}.md` — Tier 4 (domain references)
   - `{repo-name}.md` — Tier 3 (module detail)
6. Calls `assemble_knowledge` at the end

These variables are pre-exported by the main script:
- `$WIKI_CACHE` — directory for cached markdown files
- `$CONFIG_FILE` — path to knowledge-pages.json
- `$PYTHON3` — path to python3 binary
- `$KNOWLEDGE_FILE` — output path for assembled team_knowledge.md

### The `run_push()` contract

Your push script defines a `run_push()` function that takes:
- `$1` — title of the learning
- `$2` — HTML or markdown body
- `$3` — scope (cross-team, atlas, domain:{name}, repo:{name})

It resolves the target page from `$CONFIG_FILE`, fetches the current page, inserts the learning into the `## Recent Learnings` section, and updates the page via API.

### Python adapters

If your wiki's API is easier to handle in Python (e.g., Notion, SharePoint), write `pull.py` instead of `pull.sh`. The main script detects the extension and calls `python3 pull.py` instead of sourcing it. Your Python script should handle the full pull + assembly flow.

## How to Build a Tool Adapter

No tool adapters exist yet — this is a contribution opportunity. A tool adapter injects `team_knowledge.md` into another AI coding tool's config format.

A tool adapter has 3 files:

```
adapters/tools/your-tool/
  inject.sh           # Inject team_knowledge.md into the tool's config
  .toolconfig.tmpl    # Template showing the target format
  README.md           # Setup instructions + limitations
```

### The `inject.sh` contract

```bash
bash inject.sh [path/to/team_knowledge.md] [target_directory]
```

- `$1` defaults to `~/.claude/team_knowledge.md`
- `$2` defaults to `.` (current directory / repo root)

The script:
1. Reads the knowledge file
2. Checks if the target config file exists with a `## Personal` section
3. Writes the tool's config file with knowledge content + preserved personal section

### What to document in README.md

1. What the target config file is and how the tool reads it
2. Setup steps (copy script, run once, optionally auto-sync)
3. Limitations compared to Claude Code's full feature set:
   - No `@`-imports (knowledge must be inlined, not referenced)
   - No `UserPromptSubmit` hook (no auto-sync on session start)
   - No on-demand `Read` tool (all knowledge must be upfront)
   - No bidirectional push (learnings can't flow back to wiki)

## How to Contribute

### For small changes (docs, typos, category additions)

1. Fork the repo
2. Make your changes
3. Submit a PR with a clear description

### For larger changes (adapters, team packs, framework changes)

1. **Open an issue first** — describe what you want to build
2. Wait for feedback (we want to make sure it fits the architecture)
3. Fork, implement, and submit a PR

### PR Guidelines

- Keep PRs focused — one adapter or one feature per PR
- Include a clear description of what changed and why
- For wiki adapters: include setup instructions and a working example config
- For tool adapters: include a README with limitations documented
- For team packs: include a README explaining the team context
- No secrets, tokens, or credentials in any file
- Update the main README if your change adds a new capability

## Code Style

- Shell scripts: `set -euo pipefail`, functions for reusable logic
- Python: standard library only (no pip dependencies), PEP 8
- Markdown: ATX headings (`#`), fenced code blocks, tables for structured data
- No emojis in code or docs

## Architecture Principles

1. **Files over databases** — no infrastructure dependencies
2. **Wiki-agnostic** — adapters are thin; the framework doesn't assume any wiki
3. **Tool-agnostic** — the core (pull, cache, assemble) works for any AI coding tool
4. **Progressive disclosure** — don't load everything into context
5. **Auto-generation over manual maintenance** — derive what you can from source files
6. **Push requires approval** — never auto-write to external systems

## Questions?

Open an issue with the `question` label. We're happy to help you get started.
