---
name: start
description: Initialize your work session — loads vault context, checks memory gaps, and opens the visual dashboard. Use when the user says "start", "/start", "let's get going", "set me up", or at the beginning of a new work session.
---

# start

> **Finding files:** use the `vault-lookup` skill (tag-first: `vq.py find` / `search_query`, then indexes, then grep) to locate the notes this skill needs. Open only what it returns.

Initialize a work session. Load vault context, surface gaps, render dashboard.

Read `references/shared.md` — follow vault access tools, Memory loading, Fresh reads, stale data thresholds.

## Step 1 — Read in parallel

Apply Memory loading (silently). Apply Fresh reads pattern.

## Step 2 — Memory check
If `Memory.md` missing or empty: note "Memory.md not found — run `/memory` to teach me your shorthand."


## Step 4 — Surface needs attention
- Unprocessed `Inbox.md` items
- Overdue ActionItems

## Step 5 — Run `/dashboard`
Use data already loaded — do not re-read files.

## Output format
```
## Session started — [date]
[⚠️ stale data warning if applicable]
### Memory loaded
[X terms] — or — [prompt to run /memory]
### Needs attention
[overdue tasks / inbox items / blockers]
[dashboard]
```

## SkillUsage
Patch per shared.md: skill `start`.
