---
name: priorities
description: This skill should be used when the user asks "what should I work on", "what are my priorities", "what's most important today", "where should I start", "what's blocking people", or just "priorities". Shows what to work on right now by synthesising the daily summary, open PRs, chat inbox, action items, team metrics, and service health into a single ranked view.
bundle: second-brain
---

# priorities

> Vault access, structure, and common patterns are in `references/shared.md`.

> **Finding files:** use the `vault-lookup` skill (tag-first: `vq.py find` / `search_query`, then indexes, then grep) to locate the notes this skill needs. Open only what it returns.

**Always read all vault files fresh using `vault_read` — never use data already in session context from a prior session.**

Reads the vault and synthesises a ranked priority list. No external queries — uses what's already synced.

## On invocation
Read `SkillUsage.md` heading `## priorities`. If date is not "never" and not today, output `> Last used: YYYY-MM-DD (N days ago)` as the first line of your response.

## Steps

Read these files in parallel:
6. `Dashboard.md` — open PRs, especially stale or blocked ones
7. `ActionItems.md` — pending action items from Google Docs
8. `Inbox.md` — captured thoughts not yet processed
9. `Projects/*.md` — check for any flagged blockers or urgent items
10. `TrackedDocs.md` — check for any tracked docs with recent changes or pending actions
11. `TrackedChannels.md` — for each tracked channel/DM, read the latest few messages via `chat read` (limit 3). Surface anything that needs the owner's attention: direct questions, decisions waiting, FYIs from the manager, action items mentioned

## Staleness check

Check `Synced/SyncLog.md` for each sync job. Flag any that are overdue:

| Sync | Expected frequency | Overdue after |
|------|--------------------|---------------|

If any are overdue, prepend before the priority list:
```
🔄 **Syncs overdue:**
```

## Filtering resolved items


## Output format

Synthesise into a single ranked list. Group by urgency, not by source.

```

## Right now 🔴

## Today 🟡

## This week 🟢
[Anything important but not urgent — below-target services, project tasks, follow-ups]

## Inbox to process
[Items in Inbox.md that need routing — if any]
```

---

## Ranking rules

- Handoff items — who is covering on-call, any unresolved chat threads that will age badly

**Right now** = any of:
- Overdue >1 week
- Flagged critical in daily summary

**Today** = any of:
- In the daily summary high list
- Open PRs with recent activity needing attention
- Pending chat replies >2 days old
- Postmortem today that needs the owner's input or delegation

**This week** = any of:
- Open action items without a hard deadline
- Project tasks
- Follow-ups that can wait a day or two

**Formatting rules:**
- Keep each item to one line with a link where available
- Flag metric issues with emoji: `🔴 ON_CALL_HEALTH — review alert coverage`
- Flag service issues with: `⚠️ LaboratoryTreatmentService-userweb below tier target (Laboratory)`
- Do not repeat the same item in multiple sections

## Update skill tracker
After all steps complete, patch `SkillUsage.md` heading `## priorities` with today's date (YYYY-MM-DD), replacing existing content.
