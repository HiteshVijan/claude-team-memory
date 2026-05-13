# Push Protocol — Bidirectional Knowledge Flow

The push protocol is what makes Context Memory bidirectional. Instead of just loading knowledge, the system also captures new learnings and writes them back to the wiki — with human approval at every step.

## Why Push Matters

Without push, knowledge only flows one direction:

```
Wiki ──► Claude Code session ──► (knowledge dies when session ends)
```

With push, knowledge flows in a loop:

```
Wiki ──► Claude Code session ──► New learning detected
  ▲                                       │
  │                                       ▼
  └────── Wiki updated ◄──── User approves push
```

Every debugging session, every "oh, that's how that works" moment, every contact lookup — these learnings accumulate in the wiki instead of evaporating when the session ends.

## The 4-Step Push Flow

### Step 1: Detect the Learning

Claude is instructed to watch for any of these events:
- A new standard, convention, or gotcha is discovered
- A cross-service dependency or behavior is clarified
- A contact, point-of-contact, or distribution list is identified
- A troubleshooting fix is found that would save teammates time
- A workflow behavior or data flow is documented for the first time
- A transformation or coding rule is refined or corrected

When detected, Claude fills out a structured **knowledge entry** and presents it:

```
LEARNING DETECTED — review before push

  Title:    CLI Query Labels Need --label Flags
  Date:     2026-05-10
  Category: standard
  Scope:    cross-team
  Target:   → Shared Standards page
  Body:
    - Problem:  SET @@query_label only works in session mode.
                CLI queries ignore SET statements silently.
    - Solution: Use --label flags with CLI commands instead.

Push? [approve / edit / skip]
```

The user can:
- **Approve** — push as-is
- **Edit** — modify the title, category, scope, or body before pushing
- **Skip** — discard the learning (one-time fix, not worth sharing)

### Step 2: Route to Target Page

Each learning is routed to the appropriate wiki page based on its category and scope.

**Category → default scope:**

| Category | Default Scope | Target |
|---|---|---|
| Standard / convention | Cross-team | Shared standards page |
| Contact / POC | Cross-team | Shared standards page |
| Cross-service dependency | Dependency map | Dependency map page |
| Cross-service workflow | Dependency map | Dependency map page |
| Domain-specific rule | Domain | Domain page (e.g., batch-processing) |
| Troubleshooting fix | Module | Current repo's module detail page |
| Single-service workflow | Module | Current repo's module detail page |

**Scope → page ID resolution** (from `wiki-pages.json`):

| Scope | Config field |
|---|---|
| Cross-team | `_meta.shared_page_id` |
| Dependency map | `_meta.dependency_map_page_id` |
| Domain:\<name\> | `_meta.domain_pages.<name>` |
| Module:\<repo\> | `repos.<repo>.page_id` |

The user can override the default routing before approving.

### Step 3: Stage in "Recent Learnings"

**Hard rule:** All new learnings go into the `## Recent Learnings` section of the target page. They are inserted at the **top** of the section (newest first).

Learnings are NEVER inserted directly into permanent/numbered sections. That only happens during an explicit promotion review (see Lifecycle below).

**Entry format on the wiki page:**
```markdown
## Recent Learnings (Auto-Updated)

### 2026-05-10: CLI Query Labels Need --label Flags
- **Problem:** SET @@query_label only works in session mode. CLI queries ignore SET statements silently.
- **Solution:** Use --label flags with CLI commands instead.

### 2026-05-08: Contact Lookup Strategy
- **Problem:** Searching contacts by page title misses most results.
- **Solution:** Search by content, not title. Always clarify POC context first.
```

If the target page has no `## Recent Learnings` section, one is appended at the bottom before adding the entry.

### Step 4: Execute Push

The push is executed via the wiki's API:

- **Confluence:** `PUT /wiki/rest/api/content/{id}` with v1 API (v2 creates drafts)
- **Notion:** `PATCH /v1/blocks/{block_id}/children` to append to the page
- **GitBook:** Commit to the wiki repo and push
- **Git wiki:** Standard git commit + push to the wiki repo

After push:
- Clear the local cache file so the next session pull is fresh
- Include a version message describing what was added

## Staging Area Lifecycle

The "Recent Learnings" section is a **staging area**, not a permanent dumping ground. It has lifecycle rules:

### Capacity: Max 10 Entries Per Page

When the count reaches 10, Claude suggests a review before adding more. This prevents the staging area from growing unbounded.

### Review Actions (Per Entry)

During a review, each entry gets one of three actions:

| Action | What happens | When to use |
|--------|-------------|-------------|
| **PROMOTE** | Move to a permanent section of the page (e.g., new subsection under "Standards" or "Contacts") | The learning is validated and should be a permanent part of team knowledge |
| **DELETE** | Remove entirely from the page | One-time fix, no longer relevant, or superseded by a newer learning |
| **KEEP** | Leave in the staging area | Still recent and relevant, not ready to promote yet |

**Promotion is the ONLY way content enters a permanent section.** This ensures permanent sections are curated, not a firehose of auto-generated entries.

### Age Flags

- Entries older than **30 days** are flagged for review
- When the staging area exceeds **7 entries**, Claude proactively suggests a cleanup pass
- After cleanup, the wiki page version is updated with a message describing what was promoted/removed

### Example Lifecycle

```
Week 1:  Learning A pushed → Recent Learnings (1 entry)
Week 2:  Learning B pushed → Recent Learnings (2 entries)
Week 3:  Learning C pushed → Recent Learnings (3 entries)
...
Week 8:  Learning H pushed → Recent Learnings (8 entries, > 7 → cleanup suggested)

Cleanup review:
  A (7 weeks old, flagged) → PROMOTE to "## Standards" section
  B (6 weeks old, flagged) → DELETE (one-time fix, no longer relevant)
  C (5 weeks old, flagged) → PROMOTE to "## Contacts" section
  D-H                      → KEEP (still recent)

Result: Recent Learnings now has 5 entries. Two learnings are now permanent.
```

## Push Safety

- **User approval required** — every push is gated by explicit user approval
- **Never auto-push** — the AI proposes, the human disposes
- **Staging only** — new content never goes directly into permanent sections
- **Version messages** — every wiki update includes a descriptive version message for audit trail
- **Cache invalidation** — local cache is cleared after push so the next session gets fresh content

## Configuring Push for Your Wiki

The push mechanism needs:
1. **Wiki credentials** — stored in `~/.config/confluence/.env` (never committed to repos)
2. **Page mapping** — `wiki-pages.json` maps scopes to page IDs
3. **API access** — your wiki must support content updates via API

The push adapter is ~30 lines of API calls — easy to swap for any wiki with a REST API.
