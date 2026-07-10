---
description: Scaffold a new marketplace plugin — deterministic skeleton, wired into the lockfile, red-by-default until you implement its checks.
---

Invoke the `plugin-factory` skill and follow `skills/plugin-factory/SKILL.md`.

Start with the invariant-first interview: ask the user what must **always** be
true and what must **never** happen when this plugin runs, then collect the
kebab-case name and a one-line description. Run the generator:

```sh
skills/plugin-factory/scripts/scaffold-plugin.sh <name> \
  --description "<one-line description>" --invariant "<the always/never>"
```

Then walk the user through filling in the skeleton — the real invariant, real
deterministic checks in `evals/cheap/checks.sh` (this is what turns the plugin
green), and the remaining prose TODOs — and confirm with `evals/cheap/run.sh`. A
freshly scaffolded plugin is expected to be red until its checks are written.
