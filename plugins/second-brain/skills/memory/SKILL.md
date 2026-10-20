---
name: memory
description: Teach Claude your shorthand, terminology, and workplace context. Use when the user says "memory", "teach you", "remember that", "learn my shorthand", "add to memory", or wants Claude to understand their abbreviations and terminology.
---

# memory

Update `Memory.md` with new shorthand or terminology.

Read `references/shared.md` — follow vault access tools.

## Step 1 — Read current state
`mcp__obsidian__vault_read("Memory.md")` — load silently.

If it doesn't exist, create it with:
```
# Memory
Shorthand and terminology for this vault.
```

## Step 2 — Parse input
The user may provide:
- "X = Y" (explicit mapping)
- "remember that X means Y"
- Free text describing a person, project, or abbreviation

Extract the term and its meaning.

## Step 3 — Update
If the term already exists: patch the relevant section.
If new: append under the relevant section (## People, ## Projects, ## Abbreviations, or ## Other).

Format: `- **[term]** — [meaning]`

Confirm: "[term] saved to Memory.md."

## SkillUsage
Patch per shared.md: skill `memory`.
