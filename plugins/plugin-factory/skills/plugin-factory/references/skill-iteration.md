# Iterating on a skill — the wrapped loop

The plugin-factory scaffolds a plugin that is *valid, wired, and RED*. Turning that
red skeleton into a skill that actually improves a model's behavior is a separate
loop, and we don't reinvent it — we **wrap** the upstream skill-creator and add
three things it doesn't give us on its own: a file-based handoff seam, a delta gate
that scores lift over a baseline, and guards that keep the loop honest and bounded.

> **PORTABILITY:** the loop below is described in Claude Code terms — it spawns
> subagents to run the with-skill and baseline tasks. The *discipline* is
> harness-agnostic: the seam is committed files, the gate and guards are plain
> `python3` scripts, and the baseline comparison is arithmetic. On a harness with
> no subagent primitive, re-implement the "run the task twice" step with whatever
> fan-out (or even sequential runs) it has — nothing downstream depends on how the
> two runs were produced, only on the two output directories they leave behind.

## 1. Wrap, don't fork (winner #9)

`vendor/skill-creator.pin` pins the exact upstream commit of `anthropics/skills`'
`skill-creator` that this plugin builds on. We call into that harness for the
Capture-Intent → draft → run → grade → improve cycle; we do not copy its prose into
our tree. The payoff is that an upstream improvement is a one-line SHA bump in the
pin file — reviewable and revertible — instead of a merge that silently changes how
our factory behaves. The cheap pack asserts the pin stays well-formed (a real
40-hex commit, not a moving branch ref) so the wrap can't quietly drift.

## 2. The handoff seam (winner #7)

The loop's state lives in three committed files, not in one conversation's history:

- `templates/handoff/BRIEF.md` — the durable spec + invariant + eval plan.
- `templates/handoff/INTENT.md` — the frozen Capture-Intent answers.
- `templates/handoff/STUCK.md` — the bounded-iteration ledger.

Copy them next to the skill under construction and fill them in. The test is
concrete: if you closed every chat window, a fresh agent reading only these files
should be able to continue the build. That property is what lets the loop cross a
harness boundary — a Claude Code session can hand off to a Codex run to a cron job,
each reading committed state rather than a transcript the next one can't see.

## 3. The delta gate — advisory first (winner #4)

A skill is only worth shipping if it beats the no-skill (or prior-skill) baseline.
`scripts/delta_gate.py` reads a `benchmark.json` produced by the wrapped
skill-creator's `aggregate_benchmark.py` and reports the **lift**: the with-skill
pass rate minus the baseline pass rate. It prefers the named configs the aggregator
emits (`with_skill`/`new_skill` vs `without_skill`/`old_skill`) and falls back to
the pre-computed `delta.pass_rate` string.

Crucially the gate ships **advisory-only for one release**: it prints the delta and
a would-block verdict but exits 0, so a real benchmark's noise doesn't wall off the
repo before we've calibrated the threshold on live data. The gate self-declares this
— `delta_gate.py --self-test` confirms it is advisory — and only a later, deliberate
change flips it to blocking. This belongs in the aggregation + CI step, never inside
the per-run loop: gating a single iteration on its own noisy delta would make the
loop thrash.

## 4. The honesty + bound guards (winner #14)

`scripts/check_baseline_integrity.py` covers two ways the loop lies to itself:

- **Contamination.** If the baseline run accidentally saw the skill (the skill path
  leaked into the no-skill config, or both configs point at the same skill), the
  measured lift is fiction. The guard flags a baseline whose config references the
  skill under test.
- **Stuck budget.** The iterate loop is open-ended, so `STUCK.md` carries an
  explicit `budget_remaining`. `--stuck <file>` reads it and exits non-zero once the
  budget hits zero, forcing an escalation to a human instead of an unbounded spend.

Both are checkable offline (`--self-test`), so the guards are enforced by an eval,
not left as good intentions in prose.

## Putting it together

1. Scaffold the plugin (valid, wired, RED).
2. Copy the three handoff files; fill `INTENT.md` and `BRIEF.md`.
3. Run the wrapped skill-creator loop; each round logs an attempt in `STUCK.md`.
4. Aggregate to `benchmark.json`; run `delta_gate.py` (advisory) and
   `check_baseline_integrity.py` — clean baseline, budget not exhausted.
5. When the delta is a real lift and the guards are green, promote the skill and let
   the cheap/behavioral/deep tiers take over as the standing gate.
