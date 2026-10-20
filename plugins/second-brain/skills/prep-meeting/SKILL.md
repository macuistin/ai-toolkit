---
name: prep-meeting
description: Builds a short prep brief for any meeting, from its calendar entry, linked vault notes and open action items. Use when the user says "prep for", "prepare me for", "brief me on" a meeting, or names a meeting or attendee before one.
---

# prep-meeting

Produces a one-page brief for one meeting. The brief uses only what is in the vault and the calendar entry. It does not invent context.

## Steps

1. **Find the meeting.** Match the name against `Synced/Calendar.md`. If nothing matches, query the calendar connector for the next 14 days. If there are several matches, ask which one.
2. **Gather from the vault**, using `vault-lookup`:
   - Previous notes for the same meeting title or series. Take the latest two.
   - Open items in `ActionItems.md` that mention an attendee's first name or the meeting topic.
   - Any `Projects/` note whose tags match the topic.
   - Decisions in `Decisions.md` from the last 30 days that mention the topic.
3. **Write the brief:**
   - **Purpose:** from the calendar description, or "not stated".
   - **Last time:** date and two-line summary of the most recent note.
   - **Open items:** each with its owner and age.
   - **Questions to raise:** two or three, drawn from open items and decisions.
   - **Context to have ready:** links to the relevant notes.
4. **Show the brief in chat.** Save it to `Meetings/<date>-<slug>-prep.md` only if the user asks.

## Rules

- Use only what the vault and calendar contain. If a section has no source, write "nothing found in the vault" for it.
- Keep the brief to one page.
