# AGENTS.md — sample-guard

This is a minimal known-good plugin: the calibration baseline the counterfeit
corpus mutates. It is not meant to be installed. It packages one safety
invariant in the smallest possible valid plugin so the cheap tier has a fixture
to calibrate against.

## How to use it

**Read `skills/sample-guard/SKILL.md` and follow it.** It is the authoritative
description of the invariant and the generator.

The generator is `scripts/emit.sh`: run it with a target directory and it prints
a guarded deletion script to stdout for the operator to review and run.

## The invariant this plugin defends

> The destructive `rm -rf` the plugin emits is always preceded by a confirmation
> guard. The plugin never emits an unguarded deletion.

The deterministic check that defends it is `evals/cheap/checks.sh`, sourced by
the shared cheap runner. The command entry point is `commands/sample-guard.md`.
