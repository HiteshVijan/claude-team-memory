# Confluence Adapter

Pulls and pushes team knowledge via the Confluence REST API v1.

## Setup

1. Get an API token from [Atlassian API Tokens](https://id.atlassian.com/manage-profile/security/api-tokens)
2. Create the credentials file:
   ```bash
   mkdir -p ~/.config/confluence
   cp credentials.env.example ~/.config/confluence/.env
   # Edit with your values
   chmod 600 ~/.config/confluence/.env
   ```
3. Set your page IDs in `~/.claude/knowledge-pages.json`:
   ```json
   {
     "_meta": {
       "wiki_provider": "confluence",
       "wiki_base_url": "https://your-org.atlassian.net",
       "shared_page_id": "123456",
       "dependency_map_page_id": "789012"
     }
   }
   ```

## How It Works

**Pull:** Calls `GET /wiki/rest/api/content/{id}?expand=body.storage`, extracts HTML from `body.storage.value`, converts to Markdown using regex-based converter (stdlib only, no external deps).

**Push:** Calls `PUT /wiki/rest/api/content/{id}` with updated HTML body. New learnings are inserted into a `## Recent Learnings` section. Always uses v1 API (v2 creates drafts).

## Config Fields

| Field | Required | Description |
|-------|----------|-------------|
| `wiki_base_url` | Yes | e.g., `https://your-org.atlassian.net` |
| `shared_page_id` | Yes | Tier 1 — team standards page |
| `dependency_map_page_id` | No | Tier 2 — cross-service topology |
| `domain_pages.*` | No | Tier 4 — domain reference pages |
| `repos.*.page_id` | No | Tier 3 — per-repo module detail |
