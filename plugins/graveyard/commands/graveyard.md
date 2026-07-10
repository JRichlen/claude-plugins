---
description: Archive old GitHub repos into a private graveyard as git bundles, then safely delete the originals
argument-hint: "[owner] or leave blank to use your default account"
---

# /graveyard

Start the repository graveyard workflow: back up old/unused GitHub repositories
into a single private `graveyard` repo as full, restorable git bundles, then
generate a guarded script to delete the originals.

**Invoke the `graveyard` skill and follow it.** It defines the full interactive
workflow — listing candidate repos, letting the user choose, mirror-cloning and
bundling each with verified history, pushing the graveyard, confirming every
backup landed on GitHub, and producing a self-verifying deletion script that the
user reviews and runs.

Target account/owner (optional): `$ARGUMENTS`

Guardrails to honor:
- This is the user's GitHub account and deletion is irreversible. Keep them in
  the loop on which repos to archive and on the final delete.
- Never delete a repo whose bundle isn't verified present in the graveyard.
- Default the graveyard repo to **private**.
