---
name: dashboard
description: Visual dashboard showing goals, the next calendar events and open action items. Use when the user says "dashboard", "show me everything", "overview", or wants a visual summary of current state.
---

# dashboard

> **Finding files:** use the `vault-lookup` skill (tag-first: `vq.py find` / `search_query`, then indexes, then grep) to locate the notes this skill needs. Open only what it returns.

Render a visual dashboard from vault data.

Read `references/shared.md` — follow vault access tools, Fresh reads, stale data thresholds.

## Step 1 — Read in parallel

Apply Fresh reads. Apply stale data thresholds. Apply Memory loading silently.

## Step 2 — Render with show_widget
Build an HTML dashboard with sections:

- **Goals** — each goal with 🟢/🟡/🔴 status
- **Calendar** — next 3 events from Synced/Calendar.md
- **Open actions** — top 5 items from ActionItems.md that are not in Done


## SkillUsage
Patch per shared.md: skill `dashboard`.
