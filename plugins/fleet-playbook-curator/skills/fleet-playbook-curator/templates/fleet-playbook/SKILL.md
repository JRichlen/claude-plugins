---
name: __FLEET_NAME__-playbook
source-of-truth: false
description: >-
  Curated operating index for the __OWNER__/__GLOB__ fleet. Routes an operator to the
  right repo, file, and command for cross-fleet tasks. A pointer, not an authority.
---

<!-- CURATION CONTRACT — do not remove the banner or the source-of-truth:false key.
     The curator only EDITS the sections below; it never regenerates this file. -->

> ⚠️ **Curated index — NOT the source of truth.** Every claim here points to a repo and
> the commit it was read at; **verify against the linked source before acting.** If the
> freshness date below is old, distrust this and go read the repos.

**Fleet:** `__OWNER__/__GLOB__`  ·  **Last successful curation:** _(stamped by the curator)_
· if older than 14 days, treat everything below as suspect.

## How to read this

Entries are **directives with citations**, e.g.:

> **Rotate the SSH key** → check `ansible-homelab-foundation` org secrets — as of
> `abc1234` set in [`org.tf`](https://github.com/OWNER/ansible-homelab-foundation/blob/abc1234/org.tf).
> Verify: `gh secret list --org OWNER`.

Never trust a claim without a `repo@sha:path` citation next to it.

## Which repo owns what

_(curated — one row per member, each citing repo@sha)_

## Cross-repo interactions

_(curated — the tribal knowledge no single repo states)_

## Operator routes

_(curated — task → repo/file/command, each stamped)_

## Fleet membership

_(curated from the deterministic manifest — added/renamed/archived/unreadable/removed
members. Removed members are manifest-only: state that they left the fleet and when,
NEVER a content claim about them — they are not read this pass.)_

---
_This file is maintained by the fleet-playbook-curator. The claim ledger backing every
citation lives in `index.json`; the change history in `CHANGELOG.md`._
