---
name: track
description: "This skill should be used when the user says \"track\", \"untrack\", \"list tracked\", \"track this\", \"stop tracking\", \"what am I tracking\", or passes a URL, channel name, or resource to track or untrack. Infers the resource type from context. Examples: \"/track https://docs.google.com/...\", \"/track https://example.com/some-page\", \"/track #growth-data\", \"/track delete the owner // a team member\", \"/track list\"."
bundle: second-brain
---

# track

> Vault access, structure, and common patterns are in `references/shared.md`.


## Usage

`/track [command] [args]`

| Command | What it does |
|---------|-------------|
| `/track <thing>` | Add a resource. Infer type from context |
| `/track add <thing>` | Explicit add (same as above) |
| `/track delete <thing>` | Remove a tracked resource by name, URL, or channel |
| `/track list` | Show all tracked resources |
| `/track list doc` | Show tracked Google Docs only |
| `/track list link` | Show tracked web URLs only |
| `/track list slack` | Show tracked channels only |
| `/track help` | Show usage |

## Type inference

Determine the resource type from the input:
- Starts with `http://` or `https://` and is NOT a Google Doc = **link** → `TrackedLinks.md` (fetched by `sync-tracked-links`)
- Starts with `#` or `C` followed by 8+ alphanumeric chars = **slack channel** → `TrackedChannels.md`
- Matches a name already in any registry file = that type
- Unrecognised = ask: "What is this? (Google Doc, web URL, chat channel, or something else?)"

If the user describes a new type, ask what vault target it should sync to and how. Add it with type = the user's description.

## Registry files

| Type | File | Consumer |
|------|------|---------|
| link | `TrackedLinks.md` | `sync-tracked-links` (fetches with web_fetch) |

## doc add [url]

Add a Google Doc to the sync registry.

1. If no URL provided, ask for it.
2. Determine purpose. If not obvious from context, ask:
4. Validate URL contains `docs.google.com/document/d/`.
5. Read `TrackedDocs.md`, check for duplicates.
6. Append new row.

## doc remove [name or url]

1. Read `TrackedDocs.md`.
2. Match by name or URL. If ambiguous, show table and ask.
3. Show entry, confirm removal.
4. Remove row. Do NOT delete vault target files.
5. Confirm what was removed.

## doc list

1. Read `TrackedDocs.md`.
3. For each entry, check vault target exists. Flag missing: `not yet synced`.
4. Show count and `/track doc add` hint.

## link add [url]

Add a general web URL to the sync registry. Used for documentation pages, RFCs, dashboards, status pages, blog posts, or any publicly fetchable URL worth monitoring for changes.

1. If no URL provided, ask for it.
2. Validate URL starts with `http://` or `https://` and is NOT a Google Doc.
3. Ask for a short name (used as the snapshot slug).
4. Ask what type of content it is — used to route promoted content:
   - `doc` → `Learning.md`
   - `project` → `Projects/<name>.md ## Notes`
   - `decision` → `Decisions.md`
   - `general` → `Learning.md` or `Notes/<slug>.md`
5. Ask for vault target (suggest based on type above, or accept custom path).
6. Read `TrackedLinks.md`. If missing, create it:
   ```
   # Tracked Links
   > Managed by sync-tracked-links. Re-fetched on each sync run.

   | Name | URL | Type | Vault Target | Last Fetched |
   |------|-----|------|-------------|--------------|
   ```
7. Check for duplicates. If duplicate URL found, say so and stop.
8. Append new row with Last Fetched = `—`.
9. Confirm: name, URL, type, vault target. Suggest running `/sync-tracked-links` to fetch immediately.

## link remove [name or url]

1. Read `TrackedLinks.md`.
2. Match by name or URL. If ambiguous, show table and ask.
3. Show entry, confirm removal.
4. Remove row. Do NOT delete Synced/Links/ snapshot or vault target files.
5. Confirm what was removed.

## link list

1. Read `TrackedLinks.md`.
2. Display as table grouped by type.
3. Flag entries where Last Fetched = `—` as `never synced`.
4. Show count and `/track link add` hint.

## slack add [name or id]

Add a chat channel to the monitoring registry.

1. If no channel provided, ask for name or ID.
2. Resolve channel: use `slack_search_channels` to find the channel ID from a name, or accept a `C`-prefixed ID directly.
3. Ask what to monitor:
   - `digest` (default): summarise recent activity on each sync
   - `mentions`: only surface threads where the user is mentioned
   - `alerts`: only surface threads matching alert/incident patterns
4. Read `TrackedChannels.md`, check for duplicates.
5. Append new row.
6. Confirm: channel name, ID, monitor mode.

## slack remove [name or id]

1. Read `TrackedChannels.md`.
2. Match by name or ID. If ambiguous, show table and ask.
3. Confirm removal. Remove row.

## slack list

1. Read `TrackedChannels.md`.
2. Display with monitor mode for each channel.
3. Show count and `/track slack add` hint.

## (no type) - list all

When invoked as just `/track` with no arguments, show a combined view:

```
## Tracked Resources

**Documents** (N tracked)
[doc list output]

**Web URLs** (N tracked)
[link list output]

**Channels** (N tracked)
[slack list output]

Manage with: /track doc add, /track link add, /track slack add
```

## Registry formats

### TrackedDocs.md
```markdown
| Name | Type | URL | Person | Vault Target |
```

### TrackedLinks.md
```markdown
# Tracked Links
> Managed by sync-tracked-links. Re-fetched on each sync run.

| Name | URL | Type | Vault Target | Last Fetched |
|------|-----|------|-------------|--------------|
```

### TrackedChannels.md
```markdown
# Tracked Channels


| Channel | ID | Mode | Vault Target |
|---------|-----|------|-------------|
```
