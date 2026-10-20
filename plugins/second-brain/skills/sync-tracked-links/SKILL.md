---
name: sync-tracked-links
description: Re-fetch all URLs registered in TrackedLinks.md, detect changes since last sync, and promote new content directly to knowledge files. Use when the user says "sync links", "check tracked links", "update tracked URLs", or on the automated schedule. Also handles initial registration of captured URLs into the tracking registry.
bundle: second-brain
---

# sync-tracked-links

> Vault access, structure, and common patterns are in `references/shared.md`.

Re-fetches all tracked URLs, diffs against snapshots, and promotes only new/changed content to knowledge files.

## On invocation
Read `SkillUsage.md` heading `## sync-tracked-links`. If date is not "never" and not today, output `> Last used: YYYY-MM-DD (N days ago)` as the first line.

---

## Setup

Read `TrackedLinks.md`. If it doesn't exist, create it:

```markdown
# Tracked Links
> Managed by sync-tracked-links. Updated on each sync run.

| Name | URL | Type | Vault Target | Last Fetched |
|------|-----|------|--------------|--------------|
```

Also scan `Inbox.md` for any URL-only items not marked `[✓]` that aren't already in TrackedLinks.md — process these as one-time fetches.

---

## For each URL in TrackedLinks.md

1. Fetch with `WebFetch`
2. Read the previous snapshot from `Synced/Links/<slug>.md` (if exists)
3. Compare — is there new or changed content?
   - **No change + snapshot exists**: update Last Fetched date only, skip promotion
   - **Changed or first fetch**: proceed
4. Extract what's new: title, key points, decisions, learnings, actions (3–5 sentences)
5. Promote based on Type:

   | Type | Destination |
   |------|-------------|
   | `doc` | `Learning.md` under current month heading |
   | `project` | `Projects/<name>.md` under `## Notes` |
   | `decision` | `Decisions.md` |
   | `general` | `Learning.md` or `Notes/<slug>.md` if substantive |

   Format: `- **YYYY-MM-DD** — [what changed or was learned] (source: [url])`
   Add [[wikilinks]] to related vault files where relevant.

6. Write full new content as snapshot to `Synced/Links/<slug>.md`:
   ```markdown
   > Auto-synced. Last fetched: YYYY-MM-DD
   > Source: [url]

   [full extracted content]
   ```
7. Update Last Fetched in TrackedLinks.md

---

## For Inbox.md URL items

1. Fetch each URL not already marked `[✓]`
2. Extract and promote to appropriate knowledge file
3. Mark inbox item `[✓]`
4. Note in report: "Recommend adding to TrackedLinks.md for ongoing monitoring"

---

## If fetch fails

Mark `[fetch-failed: YYYY-MM-DD]` in the registry. Skip and continue.

---

## Report

- URLs checked; changed vs unchanged; failed
- What was promoted and where
- Inbox URLs processed
- URLs recommended for TrackedLinks.md registration

---

## Rules
- Only promote what's genuinely new — never re-promote unchanged content
- `Synced/Links/` stores snapshots for diffing — treat as auto-overwritten
- Never delete entries from TrackedLinks.md
- Never write distilled content to other `Synced/` files

---

## Update skill tracker
After all steps complete, patch `SkillUsage.md` heading `## sync-tracked-links` with today's date (YYYY-MM-DD), replacing existing content.
