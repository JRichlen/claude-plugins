---
description: Overview + entry point for the fleet-playbook-curator (routes to deploy or curate).
---

Invoke the `fleet-playbook-curator` skill and follow `skills/fleet-playbook-curator/SKILL.md`.

This plugin stands up daily automation that curates a living **index** for a fleet of repos
(an `owner/glob`) — one that always points at the repos as the source of truth and never
poses as it.

Pick the verb:

- **Set it up once** → `commands/deploy-fleet-playbook.md` (`/deploy-fleet-playbook <owner> <glob>`).
  One-shot, confirm-gated: creates a private per-fleet repo with the daily `Fleet sync` workflow.
- **Run a curation pass now** → `commands/curate-fleet-playbook.md` (`/curate-fleet-playbook`).
  Same PR-only, fully-cited path as the daily cron.

The invariant, the architecture, and the eval story are recorded in `docs/DESIGN.md`.
