# Plugin-factory design brief

**Status:** design of record for how this marketplace grows past its first plugin.
**How it was produced:** a multi-agent convergence pass (parallel planning grid +
creative panels, scored by independent validators) over "what should the second,
third, … plugin in this repo actually be, and what infrastructure makes each one
cheaper and safer than the last?" The raw panel produced dozens of candidates;
this brief records the **16 that survived scoring**, the ideas that were
**eliminated**, the **2 safety corrections** applied to winners before they were
allowed to ship, and the **4-wave sequencing** that orders the build.

The through-line: **the scaffold is the product.** The marketplace's real output
isn't the graveyard plugin — it's the repeatable, eval-gated machine that turns
"I have a workflow worth keeping" into a shipped, cross-harness plugin. Each wave
makes the next plugin cheaper to build and harder to get wrong.

---

## The 16 ranked winners

Ranked by leverage (impact × how many later winners it unblocks). The rank is the
build-priority signal; the wave (below) is the scheduling.

| # | Winner | What it is | Unblocks |
|---|--------|-----------|----------|
| 1 | **Deterministic `scaffold-plugin.sh` + thin skill wrapper** | One script generates a plugin skeleton (manifest, SKILL.md stub, AGENTS.md + symlinks, evals dirs) from a name. The skill is a thin prose wrapper over it, not a re-implementation. | 3, 6, 10 |
| 2 | **Generic cheap-tier core + per-plugin eval discovery, fail-closed** | The shared runner keeps generic checks and sources each plugin's `evals/cheap/checks.sh`, failing closed on any missing pack. **(Shipped — Wave 0.)** | every future plugin's safety floor |
| 3 | **Invariant-first interview** | The scaffold flow asks "what must always/never happen?" *before* prose, so every plugin is born with its safety invariant named. | 12, 13 |
| 4 | **With-skill vs baseline DELTA gate** | Score a plugin by the *lift* it gives a model over no-skill baseline, not absolute pass rate. Lives in `aggregate_benchmark.py` + a CI step — **not** `run_loop.py`. Ships **advisory-only for one release** before it can block. | 11 |
| 5 | **Portability linter** | Static check that a plugin's instructions don't depend on Claude-Code-only features (hooks, subagents) without a portable fallback. | 10 |
| 6 | **`marketplace.json` as generated lockfile** | Treat the marketplace manifest as *generated* from the plugins on disk, not hand-edited — the scaffold writes it, cheap tier verifies it. | — |
| 7 | **File-based handoff seam (`BRIEF.md` / `INTENT.md`)** | A plugin build hands off between phases (and between harnesses) through committed files, not conversation state. | 4, 14 |
| 8 | **Self-hosting golden-fixture dogfood** | The factory scaffolds a throwaway plugin as a fixture and asserts the output byte-shape — the factory tests itself. | validates 1, 3 |
| 9 | **Wrap SHA-pinned upstream skill-creator** | Don't fork the skill-creator; vendor it pinned to a SHA and wrap it, so upstream improvements are a pin bump, not a merge. | 7 |
| 10 | **AGENTS.md real-paths + placeholder-token grep gate** | Cheap check that no scaffolded file still contains `<PLACEHOLDER>` tokens and that every path named in AGENTS.md exists. | — |
| 11 | **Calibration meta-test (oracle=1.0 / nop=0.0)** | Every eval suite must include a known-good and known-bad case and prove the grader still separates them — the eval that evals the evals. | keeps 4 honest |
| 12 | **Counterfeit plugin corpus** | A set of deliberately-broken plugins (missing guard, weakened prose) the suite must reject — catches a grader that rubber-stamps. | — |
| 13 | **Red-by-default safety stub (UUID sentinel)** | A new plugin's safety check starts *failing* with a unique sentinel until the author replaces it — you can't forget to write it. | — |
| 14 | **Baseline-integrity contamination check + `STUCK.md` loop budget** | Detect when a baseline run accidentally saw the skill; bound iteration loops with an explicit stuck-file budget. | — |
| 15 | **Derived deep-tier safety-paths filter + branch-protection-as-code** | The deep-tier path filter and the four required check-names are generated/frozen in code, so branch protection can't silently drift. | — |
| 16 | **Single-turn behavioral template (max_tokens 8192) + generalize grader-model check** | A reusable promptfoo template for single-turn rubric evals; the grader-model resolves-check generalized from `sed` to `yq`/python. | — |

---

## Eliminated (and why)

- **Per-plugin cheap runners + an orchestrator (Wave 0 "Path B").** Rejected: adds
  a layer of indirection with zero benefit at one plugin. One shared runner that
  sources per-plugin fragments (Path A, winner #2) is strictly simpler and scales
  the same way.
- **A monolithic "mega-skill" that does scaffold + interview + eval authoring in
  one prose file.** Rejected: violates progressive disclosure, unmaintainable,
  and can't be tested in pieces. Split into #1/#3/#8.
- **Putting the delta gate in `run_loop.py`.** Rejected as a *placement*, not an
  idea — the gate (winner #4) is real, but computing lift belongs in
  aggregation + CI, not in the per-run loop where it would re-run baselines
  redundantly and couple scoring to execution.
- **LLM-graded structure checks.** Rejected: structure (does the file exist, does
  the manifest parse, are there placeholder tokens) is deterministic and belongs
  in the cheap tier. Spending an LLM call on it is slower, flakier, and costs
  money to answer a `test -f`.
- **Auto-publishing scaffolded plugins to the marketplace.** Rejected on safety:
  a plugin must pass its tiers and a human review before it's installable.

---

## Two safety corrections applied to winners

These are winners that were *right in spirit but unsafe as first proposed*, and
were corrected before admission:

1. **Delta gate ships advisory-only for one release (winner #4).** As first
   proposed it would immediately *block* merges on a lift threshold. But the delta
   metric is itself new and unproven — gating on an uncalibrated metric would
   reject good plugins on noise. Correction: it reports for one release cycle so
   we can see its distribution against real plugins, *then* it earns blocking
   power. (This mirrors how the deep tier was introduced as reporting-only before
   becoming required.)

2. **Red-by-default safety stub uses a UUID sentinel, not a `TODO` (winner #13).**
   A `TODO`-based stub can pass a naive grep and be silently forgotten. Correction:
   the stub fails with a *unique* sentinel string that the cheap tier greps for and
   rejects — so a plugin literally cannot go green until the author has replaced
   the generated placeholder with a real check. Fail-closed, same discipline as
   Wave 0's missing-pack rule.

---

## Four-wave sequencing

Each wave is independently mergeable and green before the next starts.

### Wave 0 — safety floor (**shipped**)
Winner **#2**. Split the cheap runner into a generic core + fail-closed per-plugin
discovery; move graveyard's checks into `plugins/graveyard/evals/cheap/checks.sh`.
Migration acceptance test proved the pre-refactor PASS set is preserved (15 → 15
+ 1 additive) with 0 failures, and fail-closed verified (missing pack → exit 1).
*This is the precondition for every later plugin: a new plugin can't ship without
its own deterministic safety checks.*

### Wave 1 — scaffold spine
Winners **#1, #3, #6, #10**, validated by **#8, #5, #13**. The deterministic
scaffold script + invariant-first interview + generated marketplace lockfile +
placeholder/real-path gates, dogfooded by the self-hosting golden fixture and
guarded by the portability linter and the red-by-default stub. *Output: `new-plugin`
produces a valid, green, safety-stubbed skeleton in one command.*

### Wave 2 — trust the evals
Winners **#12, #16, #11**. The counterfeit corpus (suite must reject broken
plugins), the reusable single-turn behavioral template, and the calibration
meta-test that proves graders still discriminate. *Output: the eval harness is
provably not a rubber stamp.*

### Wave 3 — skill authoring, wrapped
Winners **#7 → #4 (advisory) → #14**, wrapping the SHA-pinned upstream
skill-creator (**#9**). The file-based handoff seam feeds the advisory delta gate
and the contamination/stuck-budget guards. Winner **#15** (branch-protection-as-code)
lands here as the closing lock. *Output: the iterate-on-a-skill loop is a first-class,
harness-portable part of the factory.*

---

## Cross-harness constraint (applies to every wave)

Hooks and subagents are Claude-Code-specific and **do not port**. Prefer portable
skill prose + deterministic bash + pier tasks. `CLAUDE.md` / `GEMINI.md` symlink to
`AGENTS.md`. Winner #5 (portability linter) exists to enforce this mechanically so
the constraint survives contributors who only run one harness.
