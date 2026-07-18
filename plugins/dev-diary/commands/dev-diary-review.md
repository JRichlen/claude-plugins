---
description: Open a past diary entry and revise it — correct, enrich a backfilled day, or tighten the writing.
argument-hint: "[YYYY-MM-DD]   (the entry to edit; omit to pick from recent)"
---

Invoke the `dev-diary-review` skill and follow `skills/dev-diary-review/SKILL.md`.

Edit an entry that already exists in the journal repo `~/projects/dev-diary`. Pick the
day (the argument, or from the changelog), read the current entry, re-pull the day's
signals if the edit is about accuracy, **interview the user** for the correction or the
missing reasoning, apply the edits in the house style, and — once a backfilled day is
genuinely reviewed — clear its `backfilled: true` marker and footer. Keep the changelog
in sync and offer to commit. This edits existing days only; use `/dev-diary` for today.
