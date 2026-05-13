# Claude Code — Global Instructions

## Who I Work With
- Name: Jane Smith
- Role: Software Engineer, Analytics Platform team
- Email: jane.smith@acme.com

## How to Work
- Check the skill routing table BEFORE every response. If the user's intent matches, auto-invoke the skill
- Trust user's domain knowledge — verify with data/docs, not exhaustive code tracing
- When a question has multiple interpretations, ask before searching
- When a question needs context from multiple sources, search them ALL in parallel — never present partial results as the full answer
- Keep responses concise

## Team-Specific Context
- Jira: ANALYTICS project on https://your-org.atlassian.net
- Primary work: data pipeline development, workflow orchestration, query optimization
- Works across 10+ repos

## Team Standards (shared across all teammates)
@~/.claude/rules/team-standards.md

## Skill Routing (auto-generated from SKILL.md files — always up-to-date)
@~/.claude/cache/skills_routing.md

## Team Knowledge (auto-synced from wiki — the single source of truth)
@~/.claude/team_knowledge.md

<!-- BEGIN PERSONAL — everything below this line is yours, never overwritten -->
## Personal
- Prefers terse responses, no trailing summaries
- Deep SQL expertise, new to Python orchestration
- Working hours: EST, usually 9am-6pm
