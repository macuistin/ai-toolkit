---
name: setup-schedules
description: Set up, validate or repair the second-brain scheduled tasks defined in schedule.json. Use when the user says "setup schedules", "check my scheduled tasks", or "fix my automations".
---

# setup-schedules

Checks the scheduled tasks against `schedule.json` in the plugin, then creates or repairs any that are missing, misscheduled or disabled.

## Canonical tasks

Read `schedule.json`. Each entry gives an `id`, a `cron` expression (local time) and a `job` file. Add these fixed tasks as well:

| taskId | cron (local time) | Runs |
|--------|-------------------|------|
| `morning-brief` | `0 9 * * 1-5` | the morning skill |
| `sync-tracked-links` | `0 9,13,17 * * 1-5` | the sync-tracked-links skill |
| `second-brain-distill` | `0 17 * * 5` | the distill skill |

The prompt for each task is the contents of its `job` file, or for the fixed tasks, the skill name in the table.

## Steps

1. Call `mcp__scheduled-tasks__list_scheduled_tasks` to get the current tasks.
2. For each canonical task, classify it:
   - ✅ **OK**: present, `enabled: true`, and the `cronExpression` matches.
   - 🟡 **Wrong schedule**: present, but the `cronExpression` differs. Show current and expected.
   - ⏸️ **Disabled**: present, but `enabled: false`.
   - ❌ **Missing**: not present.
3. Show a status table. List any other second-brain tasks that are not in the canonical set, and leave them alone.
4. If every task is ✅, report "All N schedules healthy" with each next run time, and stop.
5. Otherwise, ask with AskUserQuestion whether to fix everything or choose which tasks to fix. Then:
   - Missing: `mcp__scheduled-tasks__create_scheduled_task` with the taskId, cron, description and prompt.
   - Wrong schedule: `mcp__scheduled-tasks__update_scheduled_task` with the corrected `cronExpression`.
   - Disabled: `mcp__scheduled-tasks__update_scheduled_task` with `enabled: true`.
6. After any change, list the tasks again and show the corrected table with next run times.
7. If a task uses connectors, remind the user to run it once from the scheduled-tasks view so that its tool permissions are approved.

## Notes

- Schedules are in local time, not UTC.
- Never delete a task the user did not ask you to remove.

## Update tracker

Patch `SkillUsage.md` heading `## setup-schedules` with today's date as a bare `YYYY-MM-DD`.
