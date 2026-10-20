---
name: vault-lookup
description: Use this skill whenever you need to find or read notes in the <vault-name> Obsidian vault, before answering questions about current state, projects, meetings, decisions or action items, and as the first step of any skill that reads the vault. Finds files by tag first.
bundle: second-brain
---

# vault-lookup

> Read-only. This skill never writes tags or files. Tags are maintained by the sync jobs and by
> skills that write (see `references/shared.md` § Tags). Rules: vault `Notes/tagging-conventions.md`.

Goal: open as few files as possible. Ask the tags which files matter, read only those (only the
sections you need), and fall back to indexes/grep only when tags don't answer it.

## Order of lookup

1. **Tags** — `vq.py find` (bash) or `search_query` (MCP). Default for any "who / which / when / what's
   the latest on X" question.
2. **Related** — `vq.py related <file>` when you have one good file and need its neighbourhood.
3. **Index** — `MEMORY.md` (CORRECTION entries) and `VaultIndex.md` → sub-index, for things tags can't
   express (status of an open loop, which file is canonical).
4. **Grep** — `vq.py find <tags> --grep <regex>` (grep only inside tagged files), then plain
   `grep -rn` / `search_simple` as the last resort.

Always still read `MEMORY.md` CORRECTION lines before stating roster/role facts.

## Tag vocabulary

| Namespace | Values (run `vq.py tags <ns>` for the live list) |
|---|---|
| `source/` | synced (under `Synced/`, machine-written), vault (curated) |
| `project/` | privacyhome, datasetcatalog, datasetownership, gdprdeletionapp, coconutclassification, dis, asclepius, portal-purge, dataclassification |
| `channel/` | chat channel a digest is about |

Reliability: `type/`, `meeting/`, `team/`, `source/` are rule-based and reliable. `person/`, `project/`,
`topic/` come from mentions, so they over-include — filter on `type/`/`meeting/` first, and treat a
hub file (ActionItems, Decisions, Learning, Issues) as "grep inside", not "read".

## A. Bash (preferred — vault folder mounted)

```
V="$SECOND_BRAIN_PATH"; Q="python3 $V/_scripts/vq.py"
```
If `ls` finds nothing and the session can request folders, request
the vault path saved in the vault config (`config/sources.json` or the setup answer) once; otherwise use section B.

| Need | Command |
|---|---|
| Everything recent about a person (no meetings) | `$Q find lujine --not meeting --since 30d` |
| Curated project notes only | `$Q find privacyhome --not synced` |
| Find a fact inside a topic | `$Q find sox --grep "opt-out"` |
| Who/what is near a file | `$Q related Projects/PrivacyHome/Notes.md` |
| Live vocabulary | `$Q tags` · `$Q tags person` |

`find` syntax: terms are ANDed (`--any` for OR). A term is a full tag (`person/alex-mclean`), a
namespace wildcard (`project/*`), or a bare name that resolves across namespaces (`alex`,
`--until`, `--path Projects/`, `--limit N` (default 15), `--hubs` to include index/log/dashboard
files (hidden by default), `--json`.

Output: `date  sizeK  path | title | tags` plus a `↳` summary line, newest first. The date is the
file's content date (filename date, else latest "last updated/synced" date). Files over 40 KB:
`--grep` or `sed -n` the section — never read them whole.

## B. MCP fallback (`mcp__obsidian__search_query`, JsonLogic)

Obsidian's index can lag a few minutes behind disk; if a result looks short, cross-check with
`search_simple` or the index.

```json
{"and": [{"in": ["person/alex-mclean", {"var": "tags"}]},
```
- Exclude: `{"!": {"in": ["source/synced", {"var": "tags"}]}}`
- Path: `{"glob": ["Projects/PrivacyHome/*", {"var": "path"}]}`
- Recent by filename date: `{"regexp": ["2026-10-(0[8-9]|1[0-9])", {"var": "path"}]}`

Then `vault_read` only the returned paths (use `vault_get_document_map` + targeted heading reads for
large ones).

## Recipes

- **Project status**: `find <project> --not synced --limit 8` → read `Projects/<P>/Notes.md` →
  `related Projects/<P>/Notes.md` → `find <project> meeting --since 14d`.
- **"What happened with <topic>"**: `find <topic> --since 30d` → `--grep` for specifics.

## When tags fail
`no tag matches` or zero results → try a broader bare term, `vq.py tags` to check spelling, then
VaultIndex → sub-index → grep. If a file clearly should have had a tag, say so in your reply (the
rules live in `_scripts/tag-rules.json`); don't edit tags from this skill.
