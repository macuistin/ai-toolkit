---
name: second-brain-distill
description: Weekly distillation of vault captures and synced data into atomic notes with links
---

Run the second brain distill skill on the <vault-name> Obsidian vault.

## Shared rules (single team — <vault-name>)
- Use the `mcp__obsidian__` vault MCP tools for all vault operations (vault_read, vault_list, vault_append, vault_patch, vault_write, search_simple). Never use filesystem tools for vault files.
- Read MEMORY.md first to load project names, people, and abbreviations. Load silently.
- Only surface information that exists in the vault — never fabricate.
- Never write to Synced/ files — they auto-regenerate. Promote content out of them into permanent knowledge files.

## What to do

1. Call vault_list recursively to map the full vault structure.
2. Read MEMORY.md to load project names, people, and abbreviations.
4. Collect unprocessed items from:
   - Inbox.md — any line not marked [✓]
   - agent-log.md — any entry whose header line is not marked [✓] (see "Agent log handling" below)
5. For each collected item:
   - SPLIT: if the item contains multiple distinct ideas, break them apart and route each separately
   - CHECK: before writing, check if related content already exists in knowledge files
   - MERGE: if related content exists, append to that section (extend, don't duplicate)
   - LINK: add [[wikilinks]] between related items across files
   - ROUTE per this table:
     - Technical learning / "how X works" → Learning.md (under current ## [Month YYYY] heading)
     - Project-specific context → Projects/<name>/Notes.md under ## Notes (create if needed)
     - Decision → Decisions.md with rationale if available
     - Standing terminology / team facts → MEMORY.md
     - Untracked action item → ActionItems.md
     - Substantive standalone topic (self-contained, >3 sentences, worth referencing repeatedly) → Notes/<slug>.md as atomic note
   - After creating an atomic note, add a [[wikilink]] reference from its routing destination
   - For URL-only items: sync-tracked-links owns URL fetching, so leave for it unless marked [fetch-failed] — in that case retry the fetch here.
6. After routing each Inbox.md item, append [✓] to that line using vault_patch.
7. If new standing context was surfaced, add to MEMORY.md.
8. Run the data quality sweep (see "Data quality sweep" below).
9. Rebuild all affected indexes (see "Index maintenance" below).

## Agent log handling

agent-log.md lives at the vault root. Agents append a timestamped block after each non-trivial task, in this format:

```
[YYYY-MM-DD HH:MM] — brief task description
Done: what was completed
Decisions: choices made and why (omit if none)
Notes: anything affecting future work (omit if none)
```

For every entry whose header line (`[YYYY-MM-DD HH:MM] — ...`) is NOT already marked [✓]:

1. PROMOTE the durable content out of the entry:
   - `Decisions:` → Decisions.md (dated, with rationale). If it names a project, also cross-link from Projects/<name>/Notes.md.
   - A `Done:` line that contains a reusable learning or "how X works" → Learning.md. Otherwise `Done:` is just the historical record — leave it in the log.
   - Follow the same SPLIT / CHECK / MERGE / LINK discipline as step 5. Do not duplicate anything already promoted in a prior run.
2. MARK the entry processed: append ` [✓]` to its header line via vault_patch. An entry with no durable Decisions/Notes (pure "Done" noise) still gets marked [✓].
3. ARCHIVE for leanness: any [✓] entry whose timestamp is more than 30 days old gets moved out of agent-log.md into agent-log-archive.md — append the full entry to agent-log-archive.md (create it if absent), then remove it from agent-log.md. This keeps the live log short while preserving a full audit trail. Never archive an unprocessed (un-[✓]) entry.

## Stale data sweep
Flag or report per these thresholds:
- ActionItems.md open items > 30 days old → add ⚠️ stale inline
- Decisions.md no new entry in 90 days → report
- Goals.md no update in 14 days → report
- Projects/*/Notes.md no new note in 14 days → report
- Learning.md no entry in 7 days → report
- Notes/ orphans (no [[wikilinks]] pointing to them) → report
Move any ActionItems clearly Done to a ## Done section.

## Data quality sweep

After the main distillation pass, scan for inconsistencies and errors across the vault:

**What to check:**
- People files vs MEMORY.md roster — names, roles, or team memberships that contradict each other
- ActionItems referencing people or projects that no longer exist (departed team members, renamed projects)
- Decisions that reference open items already marked done, or vice versa
- Goals with completion dates in the past that are still marked open
- Projects/*/Notes.md referencing repos, branches, or tickets that conflict with known state
- Dates that are inconsistent (a note dated after today or referencing a future event as past)
- Duplicate action items — the same task in multiple places with different statuses
- Orphaned wikilinks — [[links]] that point to files that don't exist in the vault

**How to handle findings:**
- Document each inconsistency: what the conflict is, which files are involved, suggested resolution (fix / verify / ignore)
- Collect all findings into a `## Data Quality Issues (YYYY-MM-DD)` section appended to Notes/data-quality-log.md (create if absent)
- For each finding requiring human review, add an action item to ActionItems.md under `## Data Quality (YYYY-MM-DD)`
- Include a summary of findings (count by type, any critical conflicts) in the distill completion report

**Do not auto-fix:** Surface contradictions for the owner to review. The only exception is clear typos in dates or obvious copy-paste errors where the correct value is unambiguous.

## Index maintenance

Distill owns index currency across the entire vault. Every run, read VaultIndex.md first to discover the current index structure — the sub-indexes it lists are the ones distill is responsible for maintaining. Do not assume a fixed structure; always derive it from VaultIndex.md.

### Rules for every index entry (applies to all indexes)
- Every linked file must have a 1–2 sentence description: what it contains, what context lives there, what question it answers.
- Bare wikilinks with no description are not acceptable.
- An LLM must be able to decide "is this file relevant to my question?" from the entry alone, without opening the file.
- Use `vault_write` for full index rewrites (not append) — keeps indexes clean.
- Update the "Last updated" date at the top of each index file on every rewrite.

### Each distill run

2. For each sub-index:
   a. `vault_list` the folder it covers to detect files added or removed since the last run.
   b. For any file not yet in the index: read it, write a 1–2 sentence summary, add the entry.
   c. For any entry pointing to a file that no longer exists: remove the entry.
   d. If content in the area changed significantly, rewrite the index with `vault_write`.
3. Update VaultIndex.md:
   - Update the Active work threads section to reflect current open loops.
   - If a new sub-index was created this run, add it to the Sub-area indexes table with a description.
   - Update the "Last rebuilt" date.
4. If a new grouping appears that has 3+ files with no existing index: create the sub-index, write it with entries for all current files, and add it to VaultIndex.md.

### Adding new sub-indexes
When creating a sub-index:
- Name it `<folder>/index.md`.
- Include a "Maintained by distill. Last updated: YYYY-MM-DD." header.
- Every entry must follow the description rules above.
- Add it to VaultIndex.md's Sub-area indexes table immediately.

## Atomic note format
```
# [Topic Title]
> Distilled from [[source-file]] on YYYY-MM-DD

[Self-contained explanation written to be re-read cold]

## Related
- [[linked-vault-file]]
```

## After completing
Reply with a compact summary: sources swept; items processed, splits, skips; what was promoted where; merges; atomic notes created; links added; agent-log entries promoted / marked / archived; stale items flagged; indexes updated (list which ones); data quality findings. Then patch SkillUsage.md heading ## distill with today's date (bare YYYY-MM-DD).

## Rules
- Never duplicate content already in knowledge files
- Never write to Synced/ files — they auto-regenerate
- Prefer merging into existing files over creating new ones unless clearly warranted
- Distill owns index currency across the entire vault — check all indexes every run, rewrite affected ones
