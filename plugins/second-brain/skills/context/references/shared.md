# Shared — second-brain plugin

Common conventions for all second-brain skills. Individual SKILL.md files reference this
instead of repeating the rules below.

## Vault access

Writes use the Obsidian MCP tools with vault-relative paths. Reads may also use the read-only
query script `_scripts/vq.py` over bash when the vault folder is mounted (see **Finding files**).

| Operation | Tool |
|-----------|------|
| Find files (tag-first) | `vq.py find` (bash) or `search_query` (MCP JsonLogic) — see the `vault-lookup` skill |
| Read a file | `vault_read` (targeted heading reads for big files) |
| List a directory | `vault_list` (last resort — prefer tags or indexes) |
| Search text | `vq.py find <tags> --grep`, then `search_simple` |
| Append | `vault_append` |
| Patch a section | `vault_patch` |
| Write / overwrite | `vault_write` |

The vault root is set by `$SECOND_BRAIN_PATH`. Personal context (project names, abbreviations,
conventions) lives in the vault: read it from `MEMORY.md` and `Projects/`. Never hardcode vault
paths or names in skill instructions.

## Finding files (tag-first)

Every note carries namespaced frontmatter tags (`type/`, `project/`, `topic/`, `person/`).
Before opening files, ask the tags which files matter — follow the **`vault-lookup`** skill:
tags (`vq.py find …` / `search_query`) → `vq.py related` → `MEMORY.md` + `VaultIndex.md` → grep.
Read only what the lookup returns. Resolve names and topics by tag; never hardcode file names.

## Tags (for skills that write)

Rules: vault `Notes/tagging-conventions.md`. Skills that write only need to:
1. Never write a bare `#word` or `#123` in prose. Wrap hashtags in backticks.
2. When rewriting a file whole, keep its existing `tags:` frontmatter line.
3. New files: start with `tags: [type/<kind>, …]` (plus `project/`, `topic/` you are sure of).
4. If the vault folder is mounted, finish with
   `python3 "$V/_scripts/tagger.py" run --paths <files you wrote>`; otherwise add a missing `type/` tag
   with `vault_patch` (frontmatter `tags`, append, createTargetIfMissing) and let the next sync do the rest.
5. Judgement tags (`topic/…`, extra `project/` tags) may be appended by hand. Never hand-edit
   `type/` or `status/` tags — they are recomputed.

## Vault structure

| Path | Purpose | Write behaviour |
|------|---------|-----------------|
| `Inbox.md` | Unrouted captures, URLs, quick notes | Append; items marked [✓] when processed |
| `Learning.md` | Permanent learnings, grouped by `## [Month YYYY]` | Append |
| `Decisions.md` | Decisions made, with context | Append |
| `ActionItems.md` | Tasks and follow-ups | Update in place; Done items move to `## Done` |
| `Goals.md` | Current goals and progress | Update in place |
| `MEMORY.md` | Project names, abbreviations, conventions | Update in place |
| `SkillUsage.md` | Last-run date per skill | Patch per skill after each run |
| `Dashboard.md` | Summary of open items | Rebuilt by its skill; Notes preserved |
| `Projects/<name>.md` | Per-project notes, plans, context | Append under `## Notes` / `## Plans` |
| `Notes/<slug>.md` | Atomic notes | Created by distill |
| `TrackedLinks.md` | Registry of URLs to monitor | Managed by sync-tracked-links |
| `Synced/` | Output of sync jobs | Overwritten each run |

Anything under `Synced/` is auto-generated and overwritten — **never write distilled or
curated content there.** Promote it to the permanent knowledge files above instead.

## Patterns

### Memory loading
Read `MEMORY.md` at the start of any skill that interprets shorthand or vault abbreviations.
Load silently — do not print its contents.

### Fresh reads
Always read vault files fresh at invocation time. Never reuse data already in context from a
prior session — it may be stale.

### Vault-only rule
Only surface information that exists in the vault. Never fabricate items, infer facts not
present, or fill gaps with assumptions. If data is missing, say so.

### On-invocation last-used check
At the start of a skill, read `SkillUsage.md` heading `## <skill-name>`. If the recorded date
is not "never" and not today, output `> Last used: YYYY-MM-DD (N days ago)` as the first line
of the response.

### SkillUsage update
After a skill completes, patch `SkillUsage.md` heading `## <skill-name>` with today's date as a
bare `YYYY-MM-DD` (replacing existing content). This is the exact format the on-invocation check
reads back.

### Date formats
Dated entries: `- **YYYY-MM-DD** — [text]`. Inbox captures may add time: `**YYYY-MM-DD HH:MM**`.

### URL capture format
When promoting fetched URL content:
```
- **YYYY-MM-DD** — [extracted summary] (source: [url])
```
Add [[wikilinks]] to related vault files where relevant.

### Stale data thresholds
Canonical thresholds for `distill` (flag) and `morning`/`priorities` (surface):

| File | Threshold | Action |
|------|-----------|--------|
| `ActionItems.md` — open items | > 30 days old | Add `⚠️ stale` inline |
| `Decisions.md` | No new entry in 90 days | Report |
| `Goals.md` | No update in 14 days | Report |
| `Projects/*.md` | No new note in 14 days | Report |
| `Learning.md` | No entry in 7 days | Report |
| `Notes/` orphans | No [[wikilinks]] pointing to file | Report |
