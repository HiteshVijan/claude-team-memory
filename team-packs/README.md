# Team Packs

Team packs are pre-configured setups for specific team types. Each pack contains:

- `team.env` — environment variables substituted into CLAUDE.md during install
- `claude-team.md.tmpl` — team-specific CLAUDE.md section (appended to the base template)
- `rules/` — (optional) team-specific rule files installed to `~/.claude/rules/`

## Creating a Team Pack

1. Copy `example-team/` to a new directory named after your team
2. Edit `team.env` with your team's details
3. Customize `claude-team.md.tmpl` with team-specific instructions
4. Add any team-specific rules to `rules/`

## Using a Team Pack

```bash
bash framework/install.sh --team-pack your-team-name
```

Or run `bash framework/install.sh` interactively and select your team pack from the list.
