# Contributing to Context Memory

Thanks for your interest in contributing! Context Memory is an open-source framework and contributions of all kinds are welcome.

## Ways to Contribute

### Wiki Adapters
The framework currently ships with a Confluence pull/push adapter. We'd love adapters for:
- **Notion** — API-based pull and push
- **GitBook** — API or git-based sync
- **Backstage** — TechDocs integration
- **Markdown repo** — git clone/pull of a wiki repo

An adapter is ~30-50 lines: a pull function (fetch page content → write to cache) and a push function (read staged content → update page via API). See `scripts/pull_knowledge.sh` for the Confluence reference implementation.

### Team Packs
A team pack is a bundle of templates and rules for a specific team type:
- `claude-base.md.tmpl` — CLAUDE.md template with team-specific sections
- `rules/*.md` — team standards (coding conventions, env config, branch rules)
- `team.env` — environment variables (team name, wiki URL, Jira project)

We'd welcome team packs for:
- **Frontend teams** (React, Angular, Vue patterns)
- **ML/Data Science teams** (experiment tracking, model registry, notebook patterns)
- **Platform/SRE teams** (incident response, runbooks, on-call context)
- **Mobile teams** (iOS/Android build pipelines, release processes)

### Skill Categories
The routing generator groups skills by category. If your team's skills don't fit the existing categories, add new ones to the `CATEGORIES` dict in `scripts/generate_skill_routing.py`.

### Documentation
- Tutorials and walkthroughs
- Video content or screenshots
- Translations

## How to Contribute

### For small changes (docs, typos, category additions)

1. Fork the repo
2. Make your changes
3. Submit a PR with a clear description

### For larger changes (wiki adapters, team packs, framework changes)

1. **Open an issue first** — describe what you want to build and why
2. Wait for feedback (we want to make sure it fits the architecture)
3. Fork, implement, and submit a PR

### PR Guidelines

- Keep PRs focused — one adapter, one team pack, or one feature per PR
- Include a clear description of what changed and why
- For wiki adapters: include setup instructions and a working example
- For team packs: include a README explaining the team context
- Update the main README if your change adds a new capability

## Code Style

- Shell scripts: `set -euo pipefail`, functions for reusable logic
- Python: standard library only (no pip dependencies), PEP 8
- Markdown: ATX headings (`#`), fenced code blocks, tables for structured data
- No emojis in code or docs (unless the user explicitly requests them)

## Architecture Principles

When contributing, keep these principles in mind:

1. **Files over databases** — no infrastructure dependencies
2. **Wiki-agnostic** — adapters are thin, the framework doesn't assume Confluence
3. **Progressive disclosure** — don't load everything into context
4. **Auto-generation over manual maintenance** — derive what you can from source files
5. **Push requires approval** — never auto-write to external systems

## Questions?

Open an issue with the `question` label. We're happy to help you get started.
