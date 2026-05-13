# Before & After: Claude Code Sessions With Context Memory

Two sessions. Same question. One has Context Memory, one doesn't.

---

## Scenario: "Add a new rule to the feature-engine service"

A developer needs to add a new scoring rule to `feature-engine`. This touches shared tables consumed by 3 downstream services.

---

### WITHOUT Context Memory

```
You: Add a new scoring rule to feature-engine that flags records
     where amount > 10000 and category = 'high-risk'

Claude: I'll help you add that scoring rule. Let me look at the codebase.

        *reads files for 2 minutes*

        I see some SQL files in the repo. Which database project should I
        target? I see references to both `acme-dev` and `acme-compute-dev`.

You: Use acme-dev.analytics_dev — never acme-compute-dev, that's Compute
     not Storage.

Claude: Got it. I'll create the query. Here's the SQL:

        CREATE TABLE acme-dev.analytics_dev.high_risk_flags AS ...

You: Wait — you need cost labels on that. Every query needs them.

Claude: What cost labels should I add?

You: team=analytics, costcenter=550100, project=analytics-platform.
     SET @@query_label for each one. And the CREATE TABLE needs an
     OPTIONS block with expiration and labels.

Claude: Updated. Now, should I create a PR?

You: Yes, but what branch are you on? PRs go to develop, never main.
     And the branch name needs to start with the ticket number.

Claude: What's the ticket number?

You: ANALYTICS-4521. And name it with flat hyphens, no slashes.

Claude: OK, creating branch analytics-4521-high-risk-scoring.
        Here's the PR.

You: Hold on — does this table get consumed downstream? I don't want
     to break data-export or the analytics-agent.

Claude: I'm not sure which services consume tables from feature-engine.
        Can you tell me?

You: enriched_features is consumed by data-export and analytics-agent.
     You need to check if your new rule's output feeds into those.

Claude: I see. Let me check...

        *10 more minutes of back-and-forth*
```

**Time spent re-explaining context: ~15 minutes**
**Risk: Claude almost used the wrong project ID and forgot cost labels**

---

### WITH Context Memory

```
You: Add a new scoring rule to feature-engine that flags records
     where amount > 10000 and category = 'high-risk'

Claude: I'll add that scoring rule. From the dependency map, I can see
        that feature-engine produces the `enriched_features` table which
        is consumed by data-export and analytics-agent — I'll make sure
        the new rule's output is compatible.

        Here's the SQL with cost labels and OPTIONS block:

        SET @@query_label = CONCAT("team:", "{{team}}");
        SET @@query_label = CONCAT("costcenter:", "{{costcenter}}");
        SET @@query_label = CONCAT("project:", "{{project}}");

        CREATE TABLE `{{target_schema}}`.high_risk_flags
        OPTIONS (
            expiration_timestamp = DATE_ADD(..., INTERVAL 30 DAY),
            labels = [("team","{{team}}"), ...]
        )
        AS
        SELECT *
        FROM `{{target_schema}}`.core_records
        WHERE amount > 10000
          AND category = 'high-risk';

        I'll create branch ANALYTICS-4521-high-risk-scoring and
        PR to develop.

        ⚠️ Note: Since enriched_features is a shared table consumed by
        data-export (WF-40) and analytics-agent, you may want to
        validate the output schema hasn't changed. Want me to check?

You: Yes, check it.

Claude: Schema is compatible — no breaking changes. PR ready.
```

**Time spent re-explaining context: 0 minutes**
**Risk: Zero — Claude auto-loaded project IDs, cost labels, branch rules, and downstream dependencies**

---

## What Claude Knew Automatically (With Context Memory)

| Knowledge | Source | Tier |
|-----------|--------|------|
| Use `acme-dev.analytics_dev`, never `acme-compute-dev` | Team Standards | 1 |
| Cost labels required on ALL queries | Team Standards | 1 |
| OPTIONS block required on all CREATE TABLE | Team Standards | 1 |
| PR target is `develop`, never `main` | Team Standards | 1 |
| Branch naming: ticket-prefix-flat-hyphens | Team Standards | 1 |
| `enriched_features` consumed by data-export + analytics-agent | Dependency Map | 2 |
| WF-30 (feature-engine) → WF-40 (data-export) timing | Dependency Map | 2 |
| SQL file patterns in feature-engine repo | Module Detail | 3 |

**Total: 8 pieces of knowledge, loaded in ~560 lines, zero user effort.**

---

## Scenario: Skill Auto-Invocation

### WITHOUT Context Memory

```
You: I need to check if the core_records table has data for last week

Claude: I can help with that. Do you have access to BigQuery?
        What project and dataset should I query?

You: Just use /bigquery

Claude: I don't have a /bigquery command available.

You: It's a skill. You should have it.

Claude: Let me check... I don't see a skill routing table.
        Can you tell me how to invoke it?
```

### WITH Context Memory

```
You: I need to check if the core_records table has data for last week

Claude: *auto-invokes /bigquery skill*

        Running query against acme-dev.analytics_dev:

        SELECT COUNT(*), MIN(created_date), MAX(created_date)
        FROM `acme-dev.analytics_dev.core_records`
        WHERE created_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)

        Results: 1,247,832 records. Date range: 2026-05-05 to 2026-05-12.
        Data looks healthy.
```

**What happened:** The skill routing table (auto-generated from SKILL.md frontmatter) matched the user's intent ("check table data") to the `/bigquery` skill and auto-invoked it. No slash command needed.

---

## Scenario: Knowledge Push-Back

### WITHOUT Context Memory

```
You: Weird — the CLI ignores SET @@query_label silently. Turns out
     you need --label flags instead when using bq query CLI.

Claude: Good to know! I'll use --label flags for CLI queries going forward.

        *knowledge dies when session ends*
        *next session: Claude uses SET @@query_label in CLI again*
```

### WITH Context Memory

```
You: Weird — the CLI ignores SET @@query_label silently. Turns out
     you need --label flags instead when using bq query CLI.

Claude: Good catch. Let me capture this as a team learning:

        LEARNING DETECTED — review before push

          Title:    CLI Query Labels Need --label Flags
          Date:     2026-05-10
          Category: standard
          Scope:    cross-team
          Target:   → Shared Standards page
          Body:
            - Problem:  SET @@query_label only works in session mode.
                        CLI queries ignore SET statements silently.
            - Solution: Use --label flags with CLI commands.

        Push to wiki? [approve / edit / skip]

You: approve

Claude: ✓ Pushed to Shared Standards page. Cache cleared — every
        teammate's next session will include this learning.

        *next session (yours or any teammate's): knowledge is auto-loaded*
```

**What happened:** The push protocol detected a reusable learning, structured it, routed it to the right wiki page, and pushed it after user approval. Every future session — for every teammate — now knows about this gotcha.

---

## The Compound Effect

| Session | Without Context Memory | With Context Memory |
|---------|----------------------|-------------------|
| **Session 1** | 15 min re-explaining context | 0 min — auto-loaded |
| **Session 10** | Still 15 min — nothing persists | 0 min + 3 learnings pushed back |
| **Session 50** | Still 15 min per session | 0 min + 15 learnings in wiki |
| **New teammate joins** | Starts from zero, 2 weeks to be productive | Day 1 — AI already knows everything |
| **After 6 months** | 750 min wasted (12.5 hours) | 50+ learnings captured, team-wide |

Context Memory isn't just faster — it gets smarter over time.
