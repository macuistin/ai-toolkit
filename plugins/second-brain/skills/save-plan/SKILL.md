---
name: save-plan
description: This skill should be used when the user says "save my plan", "save this plan to Obsidian", "save plan", "store this plan", or after completing a plan in plan mode and wanting to preserve context. Saves the current plan to Obsidian for retrieval in future sessions.
bundle: second-brain
---

# save-plan

> Vault access, structure, and common patterns are in `references/shared.md`.

Saves the current active plan from `~/.claude/plans/` to the Obsidian vault so it can be retrieved in future sessions.

## Steps

1. **Find the current plan file**:
   ```bash
   ls -t ~/.claude/plans/*.md | head -1
   ```
   Read its full content.

2. **Extract a suggested name** from the plan's title line (`# Plan: ...`) or the first heading.

3. **Prompt for plan name** — always ask, even if a name can be inferred:
   *"What should this plan be called? (suggested: `<extracted name>`)"*
   Accept the suggestion or any short descriptive name.

4. **Detect project from plan content**, then confirm:
   - "Session Replay" → `Session Replay Migration`
   - "Fast Pipeline" → `Fast Pipeline`
   - "Laboratory" / "CHIRP" → `Laboratory CHIRP`
   - "PII" → `PII Detection`
   - No clear match → no suggestion
   
   Ask: *"Which project is this for?"* — show detected project as default (or list all projects if no match):
   - Session Replay Migration
   - Fast Pipeline
   - Laboratory CHIRP
   - PII Detection
   - Other / cross-project (saves to root `Plans/`)

5. **Get current git branch** (if in a repo):
   ```bash
   git branch --show-current 2>/dev/null || echo "none"
   ```

6. **Write to `Projects/<project>/Plans/<name>.md`** (or `Plans/<name>.md` if cross-project):

   ```markdown
   ---
   saved: YYYY-MM-DD
   slug: <original-filename-without-extension>
   branch: <git-branch-or-none>
   project: <project>
   ---

   <full plan content verbatim>

   ---
   *Saved from ~/.claude/plans/<slug>.md on YYYY-MM-DD*
   *Related: [[Projects/<project>/Overview]] · [[Issues.md]] · [[Dashboard.md]]*
   ```

7. **Append log entry** to `Synced/SyncLog.md`:
   ```
   | YYYY-MM-DD HH:MM | save-plan | Saved: <project>/Plans/<name> |
   ```

## After saving

One-line confirmation: where it was saved and the plan name. Nothing else.
