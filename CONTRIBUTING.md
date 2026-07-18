# Contributing

Thanks for contributing a plugin or a fix. The [eval suite](evals/README.md) gates
every change; run `evals/cheap/run.sh` (free, offline, must exit 0) before you push,
and read `AGENTS.md` for the layout and the eval discipline.

## ⚠️ Maintainers: the paid tiers do NOT run on fork PRs

This is a real gap you must account for when reviewing external contributions.

The **behavioral (promptfoo)** and **deep (pier)** tiers cost API spend, so their CI
jobs are gated on the PR coming from this repo, not a fork:

```yaml
if: github.event.pull_request.head.repo.full_name == github.repository
```

(`grader-model`, `behavioral-run`, and `deep-run` in `.github/workflows/evals.yml`.)
Their required aggregation gates use `if: always()`, and GitHub treats a **skipped**
required check as **green**. So on a PR from a fork:

- the cheap + counterfeit + install tiers still run and gate normally, but
- the two tiers that judge **prose** (`SKILL.md`, command markdown, `AGENTS.md`) and
  **safety scripts** (pier tasks) are **skipped and report green** — no LLM ever grades
  the change, and no adversarial sandbox ever runs it.

**Therefore: a fork PR that weakens a skill's prose or a pier guard can pass all
required checks.** When reviewing an external PR that touches any `SKILL.md`,
command/agent markdown, or `plugins/*/evals/pier/**`, a maintainer must **manually
run the paid tiers** (check out the branch and run `plugins/<name>/evals/promptfoo` /
`evals/pier/run.sh` with keys) or push the branch to this repo so CI runs them, before
merging. Green required checks on a fork are necessary, not sufficient.

## Adding a plugin

Use the plugin-factory scaffold (`/new-plugin`), fill the TODOs, replace the
red-by-default `evals/cheap/checks.sh` stub with real checks for your plugin's
invariant, and add a counterfeit fixture that proves the gate bites. See
`plugins/plugin-factory/` and `evals/counterfeits/README.md`.
