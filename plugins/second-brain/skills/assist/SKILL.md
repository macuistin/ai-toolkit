---
name: assist
description: This skill should be used when the user says "assist", "help", "what can you do", "what skills do I have", or wants to know where to start. Lists the available second brain skills grouped by when to use them, flags overdue syncs and skills, then asks what they need.
bundle: second-brain
---

# assist

> Vault access, structure and common patterns are in `references/shared.md`.

Shows the available skills grouped by when you would use them, then asks what you need.

## Before displaying the menu

Read `SkillUsage.md` and `Synced/SyncLog.md` from the vault.

**Sync staleness.** For `sync-calendar` (expected twice a day, overdue after 12h) and `sync-email` (expected every 2h in working hours, overdue after 4h), check the latest run in `Synced/SyncLog.md`. Show this block only if one is overdue:
```
🔄 **Syncs overdue:**
- sync-email — last ran N hours ago (expected: every 2h)
```

**Skill overdue check.** For each skill with a threshold, compare days since its last use with its threshold. Show this block only if one is overdue:
```
⚠️ **Skills overdue — worth running:**
- /reflect — last used N days ago (threshold: 1 day)
```

Omit either block entirely if everything is current.

## Output

```
## Your second brain — what do you need?

**Start of day**
/schedule       — today's meetings, gaps and prep needs
/priorities     — ranked list of what to work on right now
/morning        — a short brief from the vault

**Mail and calendar**
/inbox-triage   — sort email into needs reply, waiting on others, FYI
/email-actions  — pull action items out of a thread
/prep-meeting <meeting> — prep brief for any meeting

**Capture**
/capture <text>            — quick thought or observation (auto-routed)
/task <text>               — new task with deadline
/context <target>: <text>  — add context to a project or decision
/learn <text>              — capture a learning or insight
/distill                   — process inbox, promote to knowledge files, flag stale data

**Documents and plans**
/track <url or channel>   — add a doc, URL or chat channel to track
/track list               — show what is tracked
/save-plan                — save the current plan to Projects/<name>/Plans/
/load-plan <name>         — restore a saved plan in a new session
/list-plans               — list saved plans grouped by project
/vault-lookup <query>     — find vault notes by tag, then index or grep

**Reviews and updates**
/goals                    — check and update current goals
/reflect                  — end-of-day wrap-up
/update                   — quick triage of stale items

**Automated**
sync-calendar   — 07:50 and 12:00 weekdays
sync-email      — every 2 hours, 08:30 to 16:30 weekdays
sync-tracked-links — 9am, 1pm, 5pm weekdays
distill         — Fridays 5pm

**Setup**
/setup-schedules — check and repair the scheduled tasks

---
What do you need?
```

After displaying the menu, wait for the response and invoke the matching skill.
