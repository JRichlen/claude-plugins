# Counterfeit corpus — proving the cheap tier is not a rubber stamp

The cheap tier (`evals/cheap/run.sh`) proves that **good** plugins pass. That is
only half of a gate. A gate that never rejected anything would also pass every
good plugin — so "green on the real repo" says nothing about whether the gate
actually *discriminates*.

This directory supplies the other half: a corpus of deliberately broken plugins,
each of which the cheap tier **must reject, and reject for the right reason**.

## How it stays safe to keep in the repo

The broken artifacts are never stored on disk — if they were, the always-on
cheap tier would trip over them (its section 2 scans every `*.json` in the whole
repo; section 1 parses every `*.sh` under `plugins/` and `evals/`).

Instead:

- **`baseline/`** is ONE all-valid plugin (`sample-guard`) plus a synthetic
  `.claude-plugin/marketplace.json`. It lives under `evals/`, not `plugins/`, so
  the real tier's plugin-specific gates never reach it, and every file in it is
  valid JSON / valid shell / portability-clean, so the generic gates (1, 2) that
  *do* scan the whole repo stay green.
- Each **`fixtures/NN-<gate>/`** ships a `DEFECT.md` (with an
  `EXPECT_FAIL_SUBSTRING=` line) and a `mutate.sh` that breaks a **copy** of the
  baseline at runtime, inside a temp dir. Nothing broken ever persists.

## What the meta-runner does

`run.sh`:

1. **Calibration.** Builds a synthetic marketplace root (copies `evals/cheap` +
   the baseline plugin + the baseline marketplace.json into a temp dir) and runs
   the copied `run.sh`. The baseline MUST be green — if a known-good plugin fails,
   the corpus is miscalibrated and every rejection below is meaningless. (This is
   winner #11, the calibration meta-test, folded into the corpus itself.)
2. **Rejection.** For each fixture: fresh copy → apply `mutate.sh` → run the
   copied `run.sh` → assert it exits non-zero **and** prints the fixture's
   `EXPECT_FAIL_SUBSTRING`. The substring check is what proves the *right* gate
   fired, not merely that something failed.

The copied `run.sh` computes its `REPO_ROOT` as its own `../..`, i.e. the temp
root — so it lints exactly the synthetic tree and nothing from the real repo.

## The fixtures — one per cheap-tier gate

| Fixture | Gate exercised | Proves |
|---|---|---|
| `01-shell-syntax` | 1 — `bash -n` | unparseable shell is caught |
| `02-json-invalid` | 2 — JSON validity | malformed manifest is caught |
| `03-name-mismatch` | 3 — marketplace→plugin wiring | a plugin renamed out of sync is caught |
| `04-frontmatter-missing` | 4 — SKILL.md frontmatter | a skill missing `description:` is caught |
| `05-unregistered-plugin` | 5 — reverse lockfile | a plugin dir with no marketplace entry is caught |
| `06-placeholder` | 6 — no unfilled `{{token}}` | a shipped template hole is caught |
| `07-agents-path` | 7 — AGENTS.md paths resolve | a broken map reference is caught |
| `08-sentinel` | 8 — red-by-default sentinel | an unimplemented eval pack is caught |
| `09-portability` | 9 — portability lint | undeclared Claude-Code-only prose is caught |
| `10-missing-pack` | 10 — fail-closed pack discovery | a registered plugin with no safety pack is caught |
| `11-weakened-guard` | the plugin's OWN sourced pack | a real safety-invariant weakening is caught |

`11-weakened-guard` is the most important: the plugin stays structurally perfect
(valid JSON, parseable shell, pack present) and only the safety invariant is
weakened. Every structural gate stays green; only the plugin's own sourced
`checks.sh` bites. It proves fail-closed discovery does more than confirm a pack
*file exists* — it proves a sourced safety pack actually **defends something**.

## Running it

```sh
evals/counterfeits/run.sh     # exit 0 = baseline green AND every counterfeit rejected
```

## Adding a fixture when you add a gate

Every new cheap-tier gate should get a counterfeit here, or the gate is unproven.
Create `fixtures/NN-<gate>/` with:

- `DEFECT.md` — describe the defect and the gate, ending with a single
  `EXPECT_FAIL_SUBSTRING=<literal from run.sh's fail message>` line.
- `mutate.sh` — takes `$1` = synthetic root, breaks exactly one thing so ONLY
  the intended gate fires. Keep the break structurally minimal; if it trips an
  earlier gate too, the earlier gate's message must still appear so the substring
  assertion holds. Materialize any broken artifact at runtime — never commit it.
