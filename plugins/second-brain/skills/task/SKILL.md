---
name: task
description: This skill should be used when the user says "add a task", "new task", "to do", "I need to", "add this to my list", or wants to track something that is not yet in GitHub. Adds a new task or action item to the vault and asks for a deadline. Optionally suggests creating a GitHub issue for larger items.
bundle: second-brain
---

# task

> Vault access, structure, and common patterns are in `references/shared.md`.

Adds a new task to the right place in the vault. Always asks for a deadline if not provided.

## Steps

1. **Parse the input** — extract the task description and any context (project, person, priority)

2. **Ask for deadline** if not already stated:
   *"When does this need to be done by?"*
   Accept: specific date, relative ("end of sprint", "this week", "next Monday"), or "no deadline"

3. **Determine destination**:
   - Personal action item (no code) → `ActionItems.md`
   - Relates to a specific project → `Projects/<name>.md` — append under `## Open tasks`
   - Follow-up for a person → `Meetings/1-1-<name>.md` — append under **Open action items on the owner**

4. **Write the task**:
   ```markdown
   - [ ] **[Task title]** — [context if any] · Due: [date or "no deadline"]
   ```

5. **Suggest GitHub issue** if the task:
   - Involves code changes or engineering work
   - Would take more than a few hours
   - Should be visible to the team

   If so, ask: *"This looks like it warrants a GitHub issue in growth-data-backlog — want me to create one?"*

## After adding

One-line confirmation: where it was saved. Nothing else.
