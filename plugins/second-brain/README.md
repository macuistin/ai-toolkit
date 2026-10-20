# second-brain

A plugin for an AI-maintained second brain in an Obsidian vault. It captures notes, tasks and decisions; syncs calendar and email into the vault; builds daily briefs; and distils raw material into linked notes.

## Install

```bash
claude plugin marketplace add <owner>/ai-toolkit
claude plugin install second-brain@ai-toolkit
```

## Setup

1. Create a vault folder and point the `SECOND_BRAIN_PATH` environment variable at it.
2. Copy `config/sources.example.json` to `config/sources.json` in the vault. Fill in your calendars and mailboxes. Keep this file out of any shared repo.
3. Connect a calendar connector and a mail connector to your runtime. The skills describe what they need ("list events in a range", "search threads", "create draft"). Map those to your connectors' tool names.
4. Run `/setup-schedules` to create the scheduled jobs from `schedule.json`.

## Skills

| Area | Skills |
|------|--------|
| Calendar and mail | `schedule`, `prep-meeting`, `inbox-triage`, `email-actions`, `sync-calendar`, `sync-email` |
| Capture and memory | `capture`, `task`, `context`, `learn`, `memory`, `vault-lookup` |
| Plans and tracking | `save-plan`, `load-plan`, `list-plans`, `track`, `sync-tracked-links` |
| Reviews | `goals`, `reflect`, `priorities`, `morning`, `dashboard`, `update` |
| Maintenance | `distill`, `setup-schedules`, `assist`, `start` |

## Rules that apply to every skill

- The vault is the source of truth. Skills read it fresh and never invent facts that are not in it.
- Synced files are overwritten by their sync. Never write curated content into them.
- Email and calendar skills are read-only. Drafts are created only after the user approves the text, and nothing is sent.
- Message bodies and attendee addresses are never stored in the vault.

## Licence

MIT. See the repository LICENSE file.
