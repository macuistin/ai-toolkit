---
name: morning
description: This skill should be used when the user says "morning", "good morning", "start of day", "what's on today", "brief me", or opens a session and wants to orient quickly. Delivers a start-of-day brief covering priorities, goals check, inbox, AI improvement tips, and vault health.
bundle: second-brain
---

# morning

> Vault access, structure, and common patterns are in `references/shared.md`.

> **Finding files:** use the `vault-lookup` skill (tag-first: `vq.py find` / `search_query`, then indexes, then grep) to locate the notes this skill needs. Open only what it returns.

Reads the vault and delivers a concise start-of-day brief. No external queries — uses what's already synced.

**Always read all files fresh — never use data already in context from a previous session. Every `/morning` run must issue new read calls for all files below, regardless of what is already in the conversation context.**

## Files to read (in parallel)

- `Goals.md` — current goals
- `Inbox.md` — captured thoughts not yet filed
- `Dashboard.md` — open PRs, any blocking someone
- `ActionItems.md` — any overdue or high-priority items
- `Decisions.md` — check last entry date
- `Learning.md` — check last entry date
- `SkillUsage.md` — last-called dates for second brain skills
- `TrackedChannels.md` — for each tracked channel/DM, read latest few messages via `chat read` (limit 3). Surface anything needing attention: direct questions, decisions waiting, FYIs from manager, action items
- `TrackedDocs.md` — check for tracked dashboards or docs with pending actions
- `TrackedLinks.md` — check for URLs not yet fetched or with `[fetch-failed]` notes

## Staleness check

Check `Synced/SyncLog.md` for each sync job. Flag any that are overdue:

| Sync | Expected frequency | Overdue after |
|------|--------------------|---------------|
| sync-tracked-links | 3x daily weekdays (9am, 1pm, 5pm) | 8h |

If any are overdue, prepend before the brief:
```
🔄 **Syncs overdue:**
```

## Filtering resolved items



## Live verification of long-running items

**Before surfacing any action item that has been "ongoing" for more than 7 days**, verify its current state against live chat. The vault accumulates data from automated syncs and bot alerts (e.g. hourly AT test failure messages) that can create the appearance of long-running team-wide blockers when the actual issue is narrower or already resolved. Duration counters like "27d+", "6mo+", or "ongoing" in `ActionItems.md` or `Dashboard.md` can drift badly.

**Trigger this check for any action item that:**
- Has a duration marker like "Nd+", "ongoing", or "6mo+"
- Has not had a vault update in >7 days
- Is labeled as a team-wide blocker or critical

**Verification steps:**
1. Search chat for the item name using `chat search`
2. Read the most recent thread activity to determine current status
3. If resolved, delegated, or narrowed in scope → patch `ActionItems.md` before including it in the brief
4. If confirmed still open → include with a note: "verified open as of [date]"
5. If no recent chat signal → mark as "unverified" and flag for the owner to check

**Special cases:**
- Any "Nd+" duration counter → verify the start date; hourly bot alerts for a single failing test can make a 3-day issue look like a 27-day blocker

**Always patch `ActionItems.md` with corrections immediately** — never silently carry a stale label forward. The next run starts from whatever is in the vault, so accuracy compounds.

## Output format

```
## Morning brief — [date]

### Start here

### Today on calendar

### Today's priorities
[3–5 items, ranked]

### Goals check-in
[One line per active goal — flag anything at risk]

### AI improvement tips

### Vault — worth checking today
[Proactively surface anything from across the vault that needs attention]

### Inbox
[Items in Inbox.md needing filing — if any]
```

---

## Rules for "Today on calendar"

Pull from `Synced/Calendar.md`. Include only events that are actionable or worth flagging:

- **Company/group all-hands or key meetings** — if today
- **Deadlines from ActionItems.md that fall today**

If nothing notable, omit the section entirely.

---

## Rules for "AI improvement tips"

- **Today's improvement suggestion** → always include this first
- **Quick wins** → pick the most relevant 1–2 based on what's in today's priorities
- **Friction to address** → mention the most impactful one if it's relevant to today's work

Format each as a one-liner: `**[Title]**: [what to do]`


---

## Rules for "Vault — worth checking today"

Proactively flag items across the vault that deserve attention. Check each of these and include only the ones that are genuinely relevant:

| What to check | Flag when |
|---------------|----------|
| `Inbox.md` | Has uncaptured items sitting there |
| `ActionItems.md` | Any items overdue or marked high priority |
| `Decisions.md` | No new entry in the last 7 days (decisions are being lost) |
| `Learning.md` | No new entry in the last 5 days (learning is going uncaptured) |
| `Goals.md` | Any goal marked ⚠️ at risk or not updated this week |
| `Projects/*.md` | Any project with no notes update in 7+ days |
| `TrackedLinks.md` | Any URL with no `Last Fetched` date, a `[fetch-failed]` tag, or last fetched >7 days ago |
| `Inbox.md` | Any bare URL items not marked [✓] — these haven't been fetched yet |

Example output:
```
### Vault — worth checking today
- 📥 **Inbox** — 3 uncaptured items need filing
- ⚠️ **Decisions** — no new entry in 8 days; any decisions made this week worth logging?
- 🎯 **Goals** — "Agentic adoption" goal hasn't been touched this sprint
- 📚 **Learning** — last entry was 6 days ago
- 🔴 **ON_CALL_HEALTH** — red; recommended action: review alert coverage and runbooks
- ⚠️ **LaboratoryTreatmentService-userweb** — below target tier (Hublytics)
```

Skip sections with nothing to flag. If everything looks healthy, write: "Vault looks healthy — nothing stale."

---

## On invocation
Read `SkillUsage.md` heading `## morning`. If date is not "never" and not today, output `> Last used: YYYY-MM-DD (N days ago)` as the first line of your response.

## Update skill tracker
After all steps complete, patch `SkillUsage.md` heading `## morning` with today's date (YYYY-MM-DD), replacing existing content.
