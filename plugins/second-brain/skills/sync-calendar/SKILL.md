---
name: sync-calendar
description: Slow sync of calendar events into the vault (today, the next 14 days, and out-of-office periods). Runs twice a day on schedule, or when the user asks to refresh the calendar ("sync calendar", "refresh my calendar").
---

# sync-calendar

Pulls calendar events into `Synced/Calendar.md`. The output is overwritten on every run, so never write notes into it.

**Mode:** scheduled (no questions, 15-minute budget, follow fallbacks) or interactive (on request).

## Inputs

- `config/sources.json` in the vault. It lists calendars, the timezone, the windows and the skip rules. Shape: `config/sources.example.json`.
- If the config is missing or has no calendars, stop and report: "No calendar sources configured. Copy config/sources.example.json to config/sources.json."

## Steps

1. **Start.** Write `Synced/Calendar.md` with frontmatter `status: running` and `startedAt`. Other skills wait while the status is `running`.
2. **Collect.** For each calendar in `calendar.sources`, list events from now to `limits.calendarDays` ahead, with a page size of 100. If the result is oversized, retry once with 7 days.
3. **Filter.**
   - Drop events where every attendee's domain is in `calendar.skipIfAllAttendeesIn`.
   - Treat all-day events whose title matches `calendar.oooKeywords` as out-of-office.
4. **Write** `Synced/Calendar.md` with three sections: **Today**, **Next N days**, **Out of office**. Each event shows its local start and end time, title, attendee count, location or video link, and event ID. Never write attendee email addresses.
5. **Finish.** Set `status: done` and `finishedAt` as the last write.
6. **Gaps.** If a calendar fails, keep its previous section, mark it "carried from YYYY-MM-DD", and record the gap in the file.
7. **After the run.** Update `SkillUsage.md` and append a row to `Synced/SyncLog.md`. Run the tagger if the vault is mounted.

## Report (scheduled mode)

Three lines at most: the number of events per section, and any gaps.
