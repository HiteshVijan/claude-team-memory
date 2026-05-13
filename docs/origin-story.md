# Why I Built Context Memory

## It Started With a Frustration

I'm a data engineer working across 14+ repositories. Every day, I work with data pipelines, SQL transformations, workflow orchestration — the kind of work where context is everything.

When I started using Claude Code, it was incredible for writing code. But every single session, I hit the same wall:

**"Which project ID do I use again?"**

I'd explain it. Claude would get it right. Session ends. Next morning — same question. And it wasn't just project IDs:

- **Multiple SOPs to check.** Our team has standards docs, pipeline runbooks, deployment guides, contact directories — scattered across wiki pages, repos, and shared drives. Every task required checking 3-5 different sources before I could even start working.

- **"Who do I contact for this?"** Need to escalate a pipeline failure? That's one contact. Infrastructure issue? Different person. Deployment approval? Another team entirely. I spent more time hunting for the right person than actually solving the problem.

- **"How does this connect to that?"** In a multi-repo ecosystem, changing one table can break five downstream services. But Claude didn't know that. It would happily modify a shared table without warning me about consumers in other repos.

- **"We already fixed this last month."** Someone on the team had debugged the exact same issue. But that knowledge died in their Claude Code session. Three weeks later, I spent 4 hours rediscovering the same fix.

## I Built It for Myself First

The first version was embarrassingly simple: a big CLAUDE.md file with all my team's standards pasted in. It worked — Claude stopped asking me for project IDs.

But the file grew. 500 lines. 800 lines. And it was static — when the team updated a standard, my file was stale. When I learned something new, it stayed in my head (or my session).

So I built the pull mechanism:
- A shell hook that fires on every session start
- Pulls the latest standards from our wiki
- Caches locally so sessions start fast
- If the cache is fresh, skip the pull — no latency

That solved the staleness problem. But it was still one-directional.

## Then Came the Push

The moment that changed everything: I spent 30 minutes debugging why `SET @@query_label` wasn't working in CLI mode. Found the fix (`--label` flags instead). Thought: *"Someone else on my team is going to hit this exact same issue next week."*

So I built the push protocol:
1. Claude detects a reusable learning
2. Presents a structured knowledge entry
3. I review it — approve, edit, or skip
4. It pushes to the wiki with proper categorization
5. Next session — for me or any teammate — the learning is auto-loaded

That was the unlock. The system started getting smarter over time, not just maintaining baseline knowledge.

## It Spread

I showed it to a teammate. They installed it in 10 minutes. Immediately: "Wait, it already knows about the branch naming rule? And the cost labels?"

Within a few weeks, the team was using it. People were pushing learnings back — contacts they'd discovered, gotchas they'd hit, pipeline behaviors they'd documented. The wiki went from a stale reference to a living knowledge base.

Then something unexpected happened: **people from other teams asked about it.**

It wasn't because the technology was novel. It was because the *behavior* was different. Engineers were collaborating with AI in a way that compounded — every session made the next one better, and every person's learning benefited everyone.

## What I Learned

### 1. Start with your own pain
I didn't set out to build a framework. I set out to stop re-typing project IDs every morning. The framework emerged from solving real, daily frustrations.

### 2. The wiki is the multiplier
A personal config file helps one person. A wiki-synced system helps a team. The bidirectional flow — pull standards, push learnings — is what creates compounding value.

### 3. Auto-generation beats manual maintenance
We had a manually-maintained skill routing table. It drifted silently — 7 skills were missing, 1 listed skill didn't exist anymore. Auto-generating it from source metadata eliminated the drift permanently.

### 4. Progressive disclosure respects the context window
Loading 2000 lines of documentation into every session wastes tokens and degrades quality. The 4-tier architecture — always load 560 lines of high-signal knowledge, load the rest on demand — is a better tradeoff.

### 5. Humans approve, AI proposes
The push protocol never auto-writes to the wiki. Every learning is presented as a structured entry for human review. This builds trust and prevents garbage from accumulating.

## The Bigger Picture

We're in the early days of human-AI collaboration. Most tools treat AI as a stateless tool — you give it context, it gives you output, context disappears.

But what if every AI session made the next one smarter? What if every team member's learning was automatically available to everyone? What if the AI remembered not just your preferences, but your entire team's institutional knowledge?

That's what Context Memory does. It's not a product — it's a pattern. And I think this pattern will become the default way engineering teams work with AI.

---

*This is an open-source framework. If your team has the same frustration, try it. If you build something better, I want to see it.*
