---
name: inbox-triage
description: Sorts email into needs reply, waiting on others and FYI, from the synced email file or a live search. Can draft replies for the user to review. Use when the user says "triage my inbox", "what needs a reply", "what's in my email", or "draft replies".
---

# inbox-triage

Sorts mail so the user can deal with it quickly. It never sends anything.

## Steps

1. **Read** `Synced/Email.md`. If it is older than 2 hours, say so and offer to run `sync-email`. If the user asks for a live check, search the mailbox connector with the same queries from `config/sources.json`.
2. **Sort** into three groups:
   - **Needs reply:** newest first. Senders listed in `email.vipSenders` go to the top.
   - **Waiting on others:** threads the user sent that have no reply yet, with the age in days.
   - **FYI:** everything else, one line each.
3. **Offer drafts.** For each item in **Needs reply**, offer to draft a reply. If the user agrees:
   - Show the draft in chat.
   - Create it as a draft in the mailbox only after the user confirms the text.
   - Never send it.
4. **Add reminders.** If the user asks, add items to `ActionItems.md` with a due date, using `email-actions` for the wording.

## Rules

- Never send mail. Drafts only, after the user has approved the text.
- Do not summarise message bodies into chat unless the user asks about a specific thread.
- Respect `email.excludeLabels`. Excluded threads do not appear in any group.
