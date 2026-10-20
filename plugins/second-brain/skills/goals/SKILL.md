---
name: goals
description: This skill should be used when the user says "goals", "check my goals", "update goals", "how am I tracking", "what are my goals", or wants to tick off something completed. Reviews, updates, or checks progress on current goals.
bundle: second-brain
---

# goals

> Vault access, structure, and common patterns are in `references/shared.md`.

> **Finding files:** use the `vault-lookup` skill (tag-first: `vq.py find` / `search_query`, then indexes, then grep) to locate the notes this skill needs. Open only what it returns.

**Always read all vault files fresh using `vault_read` — never use data already in session context from a prior session.**

Reads `Goals.md` and presents current status. Can also update goals based on input.

## On invocation
Read `SkillUsage.md` heading `## goals`. If date is not "never" and not today, output `> Last used: YYYY-MM-DD (N days ago)` as the first line of your response.

## Read mode (no input)

Display goals grouped by category with a status indicator:
- ✅ completed
- 🔄 in progress  
- ⏳ not started
- ⚠️ at risk


## Update mode (with input)

Accept natural language updates:
- `"goals: mark Fast Pipeline Phase 1 done"` → tick it off in `Goals.md`
- `"goals: add new goal — complete CHIRP migration by end of Q2"` → append to relevant section
- `"goals: note that the onboarding checklist is overdue"` → add a note under that goal

Always append — never delete goals. Mark completed ones with ✅ and date.

## Output

Show the full goals list with current status. One section per category. Brief, scannable.

## Update skill tracker
After all steps complete, patch `SkillUsage.md` heading `## goals` with today's date (YYYY-MM-DD), replacing existing content.
