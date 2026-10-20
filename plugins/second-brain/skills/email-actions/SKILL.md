---
name: email-actions
description: Pulls action items out of an email thread and adds them to ActionItems.md with a source link, skipping duplicates. Use when the user says "action items from this email", "what do I need to do from this thread", or points at a thread.
---

# email-actions

Turns requests in email into tracked action items.

## Steps

1. **Get the thread.** Use the link the user gave, or the thread from `Synced/Email.md`. Read the messages in the thread.
2. **Extract** each explicit request or commitment. For each one, record:
   - **Action:** a short imperative phrase.
   - **Owner:** the user, the other person, or "unclear". Only ask the user if the owner is unclear and the item matters.
   - **Due:** a date, if one was stated. Otherwise blank.
   - **Source:** a link to the thread.
3. **De-duplicate.** Search `ActionItems.md` for the exact action text. Skip any match.
4. **Write.** Append new items under `## Open` in `ActionItems.md`, in the format `- [ ] <action> (owner: <owner>, due: <date>, source: <link>)`.
5. **Report.** List what was added and what was skipped as a duplicate.

## Rules

- Never send, reply to or label mail.
- Do not record a request that was only implied. Ask the user, or leave it out.
- Keep sender names and addresses out of the action text. Use roles where needed, such as "the sender" or "the other party".
