# Dev-diary format guide

The house style. The goal behind every rule here is the same: an entry should be
**scannable in seconds, honest, and still useful in six months.**

## The prime directive: significance over completeness

The raw signals (commits, prompts, transcripts) are already a complete record.
Duplicating them adds no value and buries the two or three things that mattered.
Your job is to *compress with judgment*:

- A day of 30 commits is usually 2–3 real events plus churn. Write the events;
  fold the churn into one line or drop it.
- If a bullet wouldn't matter to the user next week, cut it.
- Better to have four sharp bullets than twenty mechanical ones.

## Structure

Front matter, then a TL;DR, then emoji-headed sections. The emoji are load-bearing:
they let the eye jump to the section it wants without reading headers.

| Section | What goes here | Cut if… |
|---------|----------------|---------|
| 🚀 Shipped | Done and real — merged, deployed, released | nothing shipped |
| 🔧 Changed | Meaningful WIP not yet shipped | no in-flight work |
| 🧭 Decided | Decisions **with their reasoning** | no decisions made |
| 💡 Learned | Lessons, gotchas, things that burned you | nothing learned |
| 🧵 Open threads | Unfinished business, blockers, questions | nothing open |
| ⏭️ Next | Tomorrow's first move | genuinely nothing queued |

**Delete empty sections.** A skeleton of blank headers is noise. The template is
a menu, not a checklist.

## Writing style

- **First person, terse, present-tense-ish.** A note to yourself, not a report to
  a manager. "Shipped the OIDC→WIF swap; tokens gone." not "The team successfully
  implemented a migration to eliminate token-based authentication."
- **Lead with the outcome, then the detail.** "Runners fixed — enterprise
  registration now works (`ansible-pi-cluster` #11)."
- **Every 🧭 Decided bullet answers "why".** The decision is recoverable from the
  code; the reasoning is not. That's the whole point of writing it down.
- **Concrete anchors, not vibes.** Name the repo, the hash, the PR number.

## Two hard rules

1. **Never commit a secret.** Prompt history and transcripts are full of pasted
   API tokens, keys, and credentials. This repo is on GitHub. Redact always:
   "rotated the Tailscale API key" — never the key. When in doubt, leave it out.
2. **Link durable anchors only.** Commit hashes, repo names, PR/issue numbers
   survive. Local transcript paths (`~/.claude/projects/...`) do not — never cite
   them as a reference in a committed entry. Use the `<details>` Sources block for
   provenance, and keep even that to durable anchors.

## Temporal organization

- One file per day: `entries/<YYYY>/<YYYY-MM-DD>.md`. The ISO date name sorts
  chronologically for free and is unambiguous.
- Year directories keep the tree browsable as it grows.
- `CHANGELOG.md` at the repo root is the reverse-chronological spine: one line per
  day, newest first, so you can skim months at a glance and click into any day.

## Example — good vs. noisy

**Noisy (don't):**
```
## Changed
- Made a commit bf8f355
- Made a commit 3cbde56
- Made a commit 3d2abe8
- Fixed pull request finding
- Updated the playbook
```

**Sharp (do):**
```
## 🚀 Shipped
- Enterprise-scoped GitHub runners work end to end — preflight falls back to
  ubuntu-latest when the pi cluster is down, so CI never blocks. `ansible-pi-cluster` #11

## 🧭 Decided
- **Secretless everywhere** — moved cluster + ACL auth to GitHub OIDC → Tailscale
  WIF instead of long-lived tokens. _Why:_ pasted tokens kept leaking into
  history; WIF removes the token entirely.
```
