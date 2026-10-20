---
name: learn
description: This skill should be used when the user says "learn", "note this learning", "I just learned", "interesting discovery", "worth remembering", or shares something they want to retain. Captures a learning, insight, or note from reading, a course, a conversation, or a discovery.
bundle: second-brain
---

# learn

> Vault access, structure, and common patterns are in `references/shared.md`.

Appends a learning note to `Learning.md` with a timestamp and category.

## Category detection

Infer category from the input:

| Keywords | Category |
|----------|---------|
| Java, Kafka, Vitess, CHIRP, SQL, Kubernetes, code | **Technical** |
| TL, leadership, management, feedback, team, career | **Leadership & management** |
| Anything else | **General** |

## Format

Append under the correct section heading in `Learning.md`:

```markdown
- **YYYY-MM-DD** — [the learning, in the user's own words]
```

One line per entry. Keep verbatim where possible — this is a personal knowledge log, not a summary.

## After saving

One-line confirmation: category and what was saved. Nothing else.
