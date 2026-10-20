---
name: sync-email
description: Fast sync of selected email into the vault. Covers unread mail from chosen senders or labels, and threads waiting on a reply. Runs every two hours in working hours, or when the user asks to refresh mail ("sync email", "check my mail").
---

# sync-email

Writes `Synced/Email.md`. The file is overwritten on every run. Email bodies never go into the vault.

**Mode:** scheduled (no questions, 5-minute budget, follow fallbacks) or interactive (on request).

## Inputs

- `config/sources.json` in the vault, including the `email` section. Shape: `config/sources.example.json`.
- If the config has no mailboxes, stop and report: "No mailbox sources configured."

## Steps

1. **Start.** Write `Synced/Email.md` with `status: running` and `startedAt`.
2. **Collect**, for each mailbox in `email.mailboxes`:
   - Threads matching `email.queries`, from the last `limits.emailDays` days.
   - Threads where the owner sent the last message more than `email.waitingAfterDays` ago and no reply has come in ("waiting on others").
   - Fetch metadata first: sender name, subject, date, labels, and a snippet of at most 200 characters.
3. **Exclude first.** Check labels before reading any thread. Skip any thread with a label in `email.excludeLabels`. Do not open it.
4. **Read only when needed.** Open a full message only to extract an action item, and then only the text needed for that item.
5. **Write** `Synced/Email.md` with three sections: **Needs reply**, **Waiting on others**, and **New from watched senders**. Each entry has the date, sender name (never the address), subject, a one-line summary, and a link to the thread.
6. **Finish.** Set `status: done` and `finishedAt` last.
7. **Gaps.** If a mailbox fails, keep its previous entries marked "carried from YYYY-MM-DD" and record the gap.
8. **After the run.** Update `SkillUsage.md` and append to `Synced/SyncLog.md`.

## Rules

- Read-only. This skill never sends, archives, labels or deletes mail.
- Never copy a message body into the vault. Summaries only.
