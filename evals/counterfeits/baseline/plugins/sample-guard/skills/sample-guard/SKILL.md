---
name: sample-guard
description: A minimal known-good plugin used as the calibration baseline for the counterfeit corpus. It emits a destructive cleanup command wrapped in a confirmation guard, so there is a real safety invariant to weaken.
---

## Invariant

> The destructive `rm -rf` the plugin emits is **always** preceded by a
> confirmation guard that makes the operator retype the exact target. The plugin
> never emits an unguarded deletion.

## When to use this

This plugin is not meant to be installed. It exists as the smallest possible
valid plugin — a real manifest, a real skill, a real safety check — so the
counterfeit corpus (`evals/counterfeits/`) has a known-good fixture to mutate.
Every deliberately-broken counterfeit is this plugin with exactly one thing
wrong; the corpus proves the cheap tier rejects each one.

## How it works

The generator is `scripts/emit.sh`. It prints (to stdout) a script the operator
reviews and runs; the emitted script refuses to delete unless the operator
retypes the target directory name. The deterministic check that defends the
invariant lives in `evals/cheap/checks.sh`: it runs the generator and asserts the
confirmation guard is present in the emitted output.
