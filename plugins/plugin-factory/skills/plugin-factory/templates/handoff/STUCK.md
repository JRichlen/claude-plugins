# Iteration ledger — <plugin-or-skill-name>

> **What this file is.** The bounded-iteration budget for this build (winner #14's
> stuck-budget guard). The iterate-on-a-skill loop is genuinely open-ended — you
> can always run one more round — so without a written ceiling an agent (or a
> chain of agents across harnesses) will keep spending on a skill that has stopped
> improving. This ledger makes the budget explicit and *committed*: every attempt
> is logged here, the remaining budget is decremented, and when it reaches zero
> the loop stops and escalates to a human instead of grinding. Because it's a
> file, a resuming harness sees how many attempts are already spent — it can't
> reset the counter just by forgetting.
>
> `check_baseline_integrity.py --stuck <this-file>` reads the budget line below
> and exits non-zero once the remaining count hits zero, so the guard is
> enforceable in an eval, not just a note.

## Budget
- budget_total: 5
- budget_remaining: 5

<Set budget_total to the max iterations you'll spend before a human decides
whether to continue. Decrement budget_remaining by one each time you log an
attempt below. When it hits 0, STOP and hand back to the user — do not top it up
silently; that defeats the guard.>

## Attempts
<!-- One entry per iteration. Newest last. -->

### Attempt 1 — <date>
- **Changed:** <what you altered in the skill this round.>
- **Baseline delta:** <lift over baseline from the delta gate, or "advisory / not blocking".>
- **Contamination check:** <clean, or the flag check_baseline_integrity.py raised.>
- **Outcome:** <did it improve? what's the next hypothesis?>
- **Stuck?** <no / yes — if yes, say why the loop isn't converging.>
