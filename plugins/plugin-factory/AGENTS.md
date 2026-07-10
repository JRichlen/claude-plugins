# AGENTS.md — plugin-factory

This plugin scaffolds a **new marketplace plugin skeleton in one command**. A
deterministic generator emits a valid `plugin.json`, an invariant-first
`SKILL.md`, the cross-harness `AGENTS.md` + `CLAUDE.md`/`GEMINI.md` symlinks, a
command stub, and a red-by-default eval pack — then wires the new plugin into the
marketplace lockfile. It exists so adding a plugin is a solved, repeatable step
instead of a dozen hand-edits that each risk a red cheap tier.

## How to use it

**Read `skills/plugin-factory/SKILL.md` and follow it.** It is the authoritative
description: the invariant-first interview to run before scaffolding, how to
invoke the generator, and the fill-in order afterward.

The generator is `skills/plugin-factory/scripts/scaffold-plugin.sh`:

```sh
skills/plugin-factory/scripts/scaffold-plugin.sh <name> \
  --description "<one-line description>" --invariant "<always/never>"
```

The command entry point a user invokes is `commands/new-plugin.md`.

## The invariant this plugin defends

> Every plugin the factory produces starts **valid, wired, and RED**: a parseable
> manifest whose name matches its directory, an entry in the marketplace
> lockfile, and an `evals/cheap/checks.sh` that fails closed until a human writes
> real checks. The factory never emits a skeleton that could show green with zero
> safety coverage.

The deterministic checks that defend it live in `evals/cheap/checks.sh`, which
dogfoods the generator: it scaffolds a throwaway plugin into a temporary
marketplace root and asserts the output shape (full skeleton, symlinks wired,
valid manifest, invariant section present, no unfilled placeholders, sentinel
stub present, exactly one lockfile entry). If the generator regresses, that eval
goes red.
