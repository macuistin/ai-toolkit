---
name: capture
description: This skill should be used when the user says "capture", "note this", "remember", "log this", "write this down", or just wants to record something quickly without interrupting their flow. Captures a thought, idea, observation, or anything that needs recording and routes it to the right place automatically.
bundle: second-brain
---

# capture

> Vault access, structure, and common patterns are in `references/shared.md`.

Takes freeform input and routes it to the right place in the Obsidian vault with a timestamp.

## Routing logic

Read the input and decide where it belongs:

| If the input mentions... | Route to |
|--------------------------|----------|
| A project name (Session Replay, Fast Pipeline, Laboratory, PII) | `Projects/<name>.md` — append under a `## Notes` section |
| A decision or "we decided" / "decided to" | `Decisions.md` — append as a new entry with template |
| A task or "need to" / "to do" / "follow up" | `ActionItems.md` — append under **In Progress** or **To Do** |
| Anything else | `Inbox.md` — append as a timestamped bullet |

When in doubt, route to `Inbox.md`. It's better to capture than to overthink routing.

## URL handling

If the input is a URL (or contains one), fetch it with `WebFetch` before routing:

1. Fetch the URL and extract: title, key points, decisions, learnings, and action items (3–5 sentences)
2. Route the extracted content (not the bare URL) using the routing logic above — infer the destination from the page content
3. Format as: `- **YYYY-MM-DD** — [extracted summary] (source: [url])`
4. Add [[wikilinks]] to related vault files where appropriate
5. After capturing, ask: "Want me to add this to TrackedLinks.md so I check it for changes on each sync?"

If the fetch fails, capture the bare URL to `Inbox.md` with a `[fetch-failed]` note so `/distill` can retry it.

## Format

### For Inbox.md
```markdown
- **YYYY-MM-DD HH:MM** — [the captured text]
```

### For Projects/<name>.md
Append a `## Notes` section if it doesn't exist, then add:
```markdown
- **YYYY-MM-DD** — [the captured text]
```

Same — append under `## Notes`:
```markdown
- **YYYY-MM-DD** — [the captured text]
```

### For Decisions.md
Append a minimal entry:
```markdown
## YYYY-MM-DD — [inferred title]
**Context:** [captured text]
**Decision:** [if stated]
**Consequences:** [if stated]
```

### For ActionItems.md
Append under **In Progress** or **To Do** as a new task:
```markdown
### [inferred task title]
- **Notes**: [captured text]
```

## After capturing

Confirm in one line: where it was saved and what was written. Nothing else.
