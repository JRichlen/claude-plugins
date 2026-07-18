# AGENTS.md — fleet-playbook-curator

Deploy daily GitHub automation that curates a living, self-invalidating operating index (a 'fleet playbook') for a glob of repos — always pointing at the repos as the source of truth, never posing as it.

## How to use it

Read `skills/fleet-playbook-curator/SKILL.md` and follow it — it is the authoritative
description of this plugin's workflow and the invariant it defends.

The command `commands/fleet-playbook-curator.md` is the entry point a user invokes.

## The invariant this plugin defends

The fleet-playbook is a curated INDEX that only says where truth lives and when it was read: every substantive claim carries a repo@sha:path citation and an as-of stamp, uncited claims are omitted or flagged stale rather than asserted, and the agent's interpretation reaches main only through a reviewed PR while the deterministic detector auto-commits only facts.

The deterministic checks that defend it live in `evals/cheap/checks.sh` and run
as part of the marketplace cheap tier.
