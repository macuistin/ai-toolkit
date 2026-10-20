---
name: list-plans
description: This skill should be used when the user says "list plans", "what plans do I have", "show my plans", "what have I saved", or before running /load-plan to see what is available. Lists all saved plans in Obsidian.
bundle: second-brain
---

# list-plans

> Vault access, structure, and common patterns are in `references/shared.md`.

> **Finding files:** use the `vault-lookup` skill (tag-first: `vq.py find` / `search_query`, then indexes, then grep) to locate the notes this skill needs. Open only what it returns.

**Always read vault files fresh using `vault_read`/`vault_list` — never use data already in session context from a prior session.**

Lists all saved engineering plans from the Obsidian vault, grouped by project.

## Steps

1. **List all plan files** using `vault_list` on each project's Plans/ folder:
   - `Projects/Session-Replay-Migration/Plans/`
   - `Projects/Fast-Pipeline/Plans/`
   - `Projects/Laboratory-CHIRP/Plans/`
   - `Projects/PII-Detection/Plans/`
   - `Plans/` (root — cross-project)

2. **For each plan file found** (excluding README.md), read its frontmatter to extract:
   - `saved` date
   - `branch`
   - `project` name

3. **Display grouped by project**:

```
## Saved plans

**Session Replay Migration**
- [Plan name](path) — saved YYYY-MM-DD, branch: sr-extract/01-base

**Fast Pipeline**
- [Plan name](path) — saved YYYY-MM-DD, branch: none

**Cross-project / unassigned** (Plans/)
- [Plan name](path) — saved YYYY-MM-DD

---
Run /load-plan <name> to restore any plan.
```

4. If no plans found anywhere: *"No plans saved yet. Run /save-plan after completing a plan in plan mode."*

## After listing

Display the list, then wait. Do not automatically load any plan.
