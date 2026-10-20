---
name: load-plan
description: This skill should be used when the user says "load plan", "restore plan", "what was my plan for X", "load plan context", "continue working on X", or starts a session referencing previous engineering work. Loads a saved plan from Obsidian to restore project context in a new session.
bundle: second-brain
---

# load-plan

> Vault access, structure, and common patterns are in `references/shared.md`.

> **Finding files:** use the `vault-lookup` skill (tag-first: `vq.py find` / `search_query`, then indexes, then grep) to locate the notes this skill needs. Open only what it returns.

**Always read vault files fresh using `vault_read` — never use data already in session context from a prior session.**

Retrieves a saved plan from the Obsidian vault and displays it in full so the current session has complete context to continue the work.

## Steps

1. **If no name given** — run `/list-plans` to discover all available plans across all project subfolders (`Projects/*/Plans/` + root `Plans/`), then ask:
   *"Which plan do you want to load?"*
   Wait for the user to select one before continuing.

2. **If a name is given** (e.g., `/load-plan Session Replay`):
   - Search across all Plans/ locations (same as list-plans)
   - Fuzzy-match against the given name
   - If multiple matches, show them and ask which one
   - If no match, run list-plans and ask

3. **Read the plan file** from Obsidian using `vault_read`

4. **Display the full plan content** — reproduce it verbatim. Don't summarise.

5. **Surface related vault notes** from frontmatter and auto-detected links:
   - Link to `[[Projects/<project>/Overview]]` if applicable

6. **If the plan references a git branch** (from frontmatter `branch:`):
   - Note: *"This plan was last worked on branch `<branch>`. Run `git checkout <branch>` to resume."*

## After loading

Display the full plan, then the contextual notes. Complete context restoration — nothing should be missing.
