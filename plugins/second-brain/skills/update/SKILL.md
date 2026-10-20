---
name: update
description: Quick triage of stale items and memory gap check. Use when the user says "update", "/update", "check in", "triage", "what's stale", or wants a fast status sweep. Add "--comprehensive" for a deep scan of email, calendar, and chat.
---

# update

> **Finding files:** use the `vault-lookup` skill (tag-first: `vq.py find` / `search_query`, then indexes, then grep) to locate the notes this skill needs. Open only what it returns.

Fast triage: stale items, memory gaps, open loops.

Read `references/shared.md` — follow vault access tools, Memory loading, Fresh reads, and Stale data thresholds.

## Step 1 — Read in parallel

Apply Memory loading silently. Apply Fresh reads. Apply stale data thresholds.

## Step 2 — Triage output
```
### 🔴 Overdue or stale (needs action now)
[Items past due date, decisions with no owner, etc.]

### 🟡 Needs attention this week
[High-priority action items, goals at risk]

### 📥 Inbox to process
[Unprocessed items in Inbox.md]

### 🧠 Memory gaps
[Missing shorthand entries, person files with no recent context]

### ✅ Looks good
[Everything else]
```

## Comprehensive mode
If `--comprehensive` was passed, also search:
- chat (via chat MCP) for unresolved threads >48h old
- Calendar (via Calendar MCP) for upcoming meetings with no prep notes

## SkillUsage
Patch per shared.md: skill `update`.
