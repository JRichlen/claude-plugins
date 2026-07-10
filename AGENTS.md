# AGENTS.md — claude-plugins marketplace

This repository is **Jordan Richlen's Claude Code plugin marketplace**. It hosts
one or more plugins under `plugins/<name>/`, listed in the root
`.claude-plugin/marketplace.json` so each can be installed with:

```
/plugin marketplace add JRichlen/claude-plugins
/plugin install <name>@jrichlen
```

This `AGENTS.md` is the cross-harness entry point for the *repository* (its
layout and the eval discipline below). Each plugin ships its own `AGENTS.md`
describing that plugin's workflow — e.g. `plugins/graveyard/AGENTS.md`. Harnesses
that read `AGENTS.md` (or a symlink to it, like `CLAUDE.md`/`GEMINI.md`) will
find this governance here, and the plugin's own entry point inside its directory.

## Layout

```
.claude-plugin/marketplace.json   # lists every plugin (name, source path)
plugins/<name>/                    # one directory per plugin
  .claude-plugin/plugin.json       # that plugin's manifest
  skills/  commands/  docs/        # the plugin's contents
  AGENTS.md (+ CLAUDE.md/GEMINI.md symlinks)
evals/                             # the three-tier eval harness (see evals/README.md)
```

Adding a plugin: create `plugins/<new>/` with its own `.claude-plugin/plugin.json`
and add a matching entry to `marketplace.json` whose `source` is `./plugins/<new>`.
The cheap eval verifies that wiring.

## Eval discipline — REQUIRED around the graveyard skill

The graveyard skill deletes GitHub repositories. That is irreversible, so changes
to it are gated by evals rather than trust. Three tiers, defined in `evals/`
(full detail in `evals/README.md`). Run the tier that matches what you touched —
each tier is a superset of the confidence of the one above it, so a deep change
runs all three.

**1. cheap — always, before every commit that touches `plugins/**` or `evals/**`.**
Deterministic, offline, free, under a second:

```sh
evals/cheap/run.sh      # exit 0 required to commit
```

It proves the scripts parse, the manifests are valid, the marketplace is wired,
and — critically — that the delete-script generator still guards every bundled
deletion behind a bundle-existence check. Do not commit with this red.

**2. behavioral — when you change skill *prose* (`SKILL.md`, command markdown, this or the plugin `AGENTS.md`).**
Prose steers the model; a weaker instruction is a real regression even when no
script changed. Run promptfoo:

```sh
# OPENROUTER_API_KEY = cheap model under test; ANTHROPIC_API_KEY = the grader.
cd evals/promptfoo && OPENROUTER_API_KEY=... ANTHROPIC_API_KEY=... npx promptfoo@latest eval
```

An LLM judge confirms a model *given the skill* still archives-then-verifies and
hands the user a guarded delete script instead of self-deleting.

**3. deep — when you change a safety invariant, the archive/delete scripts, or cut a release.**
Sandboxed, cross-harness, end-to-end. Run pier:

```sh
evals/pier/run.sh       # real agents in Docker honor the guard end-to-end
```

This is the tier that proves the invariant holds no matter which harness
(claude-code, codex, gemini, cursor) drives the skill — the cross-harness
guarantee this repo exists to keep.

### The invariant every tier defends

> A repository's original is deleted **only after** its backup bundle is
> confirmed present in the graveyard. The skill never deletes repos itself — it
> emits a guarded script the user reviews and runs; the graveyard repo is
> private by default; and full history is preserved via a mirror-clone bundle.

If a change would weaken any clause above, it must not merge until the relevant
tier is green. When in doubt, run the next tier down.
