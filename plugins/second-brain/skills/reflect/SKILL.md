---
name: reflect
description: This skill should be used when the user says "reflect", "end of day", "EOD", "what did I do today", "wrap up", "how did today go", or wants to close out the day. Runs an end-of-day or end-of-week reflection, capturing wins, learnings, and anything to carry forward.
bundle: second-brain
---

# reflect

> Vault access, structure, and common patterns are in `references/shared.md`.

> **Finding files:** use the `vault-lookup` skill (tag-first: `vq.py find` / `search_query`, then indexes, then grep) to locate the notes this skill needs. Open only what it returns.

**Always read all vault files fresh using `vault_read` — never use data already in session context from a prior session.**

A lightweight end-of-day review. Captures what happened, surfaces anything worth logging, and clears the decks.

## On invocation
Read `SkillUsage.md` heading `## reflect`. If date is not "never" and not today, output `> Last used: YYYY-MM-DD (N days ago)` as the first line of your response.

## Steps

1. **Read context** (in parallel):
   - `Dashboard.md` — any PRs that moved today
   - `Inbox.md` — anything captured during the day

2. **Ask** (if not already provided as input):
   - What went well today?
   - Any follow-ups or things to carry to tomorrow?

3. **Write**:
   - If follow-up tasks → append to `ActionItems.md` or `Inbox.md`
   - If learning or insight → suggest `/learn <text>`

## Output

Brief summary of what was captured and where it was saved. Nothing else.

## Update skill tracker
After all steps complete, patch `SkillUsage.md` heading `## reflect` with today's date (YYYY-MM-DD), replacing existing content.
