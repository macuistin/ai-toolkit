---
name: context
description: This skill should be used when the user says "add context to", "note about", "update the project note", "add this to", "record this for", or wants to annotate something they just learned without replacing existing content. Adds context, notes, or new information to an existing project, person, decision, or meeting note.
bundle: second-brain
---

# context

> Vault access, structure, and common patterns are in `references/shared.md`.

> **Finding files:** use the `vault-lookup` skill (tag-first: `vq.py find` / `search_query`, then indexes, then grep) to locate the notes this skill needs. Open only what it returns.

Appends new context to the right note in the vault. Never overwrites — always appends.

## Usage patterns

```
/context Session Replay — the backfill needs to happen before we cut over consumers, confirmed with a stakeholder
/context a team member — showed great initiative proposing the backfill approach in today's meeting
/context decision — we chose to use strangler pattern for Fast Pipeline rollout rather than big-bang
```

## Steps

1. **Parse the target** from the input — project name, person name, or "decision"
2. **Find the right note**:
   - Project name → `Projects/<name>.md`
   - "decision" or "we decided" → `Decisions.md`
   - "action item" or "to do" → `ActionItems.md`
3. **Append** under a `## Notes` section (create it if missing) with timestamp:
   ```markdown
   - **YYYY-MM-DD** — [the context text]
   ```

## After adding

One-line confirmation: which file was updated. Nothing else.
