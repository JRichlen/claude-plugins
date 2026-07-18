# AGENTS.md — dev-diary

Keep a scannable developer journal that writes itself. Two entry points:

- **`/dev-diary [date]`** → the `dev-diary` skill. Discover a day's work from local
  signals, interview the user, write a dated entry. See `skills/dev-diary/SKILL.md`.
- **`/dev-diary-review [date]`** → the `dev-diary-review` skill. Revise a past entry
  (correct, enrich a backfilled day, tighten). See `skills/dev-diary-review/SKILL.md`.

Read the relevant SKILL.md and follow it — it is the authoritative workflow.

## The tool/journal split this plugin depends on

This plugin is **only the tool** and is shareable. The **journal is a separate,
private repo at `~/projects/dev-diary`** — entries under `entries/<YYYY>/`, a
reverse-chron `CHANGELOG.md` spine, and the house style in
`skills/dev-diary/references/format-guide.md`. Entries are never written into this
marketplace repo. Both skills reference the journal by that absolute path, so the
tool and the diary stay decoupled.

## Invariants the skills defend

- **Significance over completeness.** An entry is the *judged* version of a day —
  the two or three things that mattered — not a transcript of every commit.
- **Every decision records its why.** The reasoning is the part code can't
  reconstruct; it's the reason the journal exists.
- **Never commit a secret.** Prompt history and transcripts contain pasted tokens
  and keys; entries redact them by rule. The journal is private, but treated as if
  it isn't.
- **Backfilled ≠ reviewed.** Reconstructed days carry `backfilled: true` + a
  footer; `/dev-diary-review` clears that marker only once the user actually vets
  the day.
