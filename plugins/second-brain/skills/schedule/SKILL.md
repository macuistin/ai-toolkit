---
name: schedule
description: Day view built from the synced calendar. Shows today's meetings, gaps, out-of-office periods and meetings that need prep. Use when the user asks "what's my day", "what's on today", "my schedule", or "what's coming up this week".
---

# schedule

Builds a day view from `Synced/Calendar.md`. It does not query the calendar directly. That keeps the answer fast and consistent with the morning brief.

## Steps

1. Read `Synced/Calendar.md`. If `status` is `running`, say the calendar is syncing and wait for it to finish.
2. If `Synced/Calendar.md` is more than 4 hours old, say so and offer to run `sync-calendar` first. Do not block on it.
3. Build the view for today, or for the day or week the user asked about.
4. Flag these, in this order:
   - Out-of-office today or tomorrow, with anything that needs handing off.
   - Back-to-back meetings with no gap of 15 minutes or more.
   - Meetings in the next 24 hours that have no prep note. Check the vault for a note matching the meeting title or attendees, using `vault-lookup`.
   - Any gap of 60 minutes or more, as focus time.
5. Show a short timeline: time, title, flags. Keep it under 15 lines.

## Rules

- Read-only. Never create, move or decline calendar events.
- Use the vault's own notes for prep status. Do not guess what a meeting is about from its title alone.
