---
name: second-opinion
description: >-
  Offer-only validation pipeline for a verdict or recommendation. Use when the
  user asks to validate, verify, fact-check, or get a second opinion on a claim
  or recommendation — "are you sure", "double-check this", "second opinion".
  Batches fact-checking against sources, adds scoped advisor personas for the
  angles that need judgment, then re-emits the response grouped into verified,
  flagged, and conflict, with a mandatory validation delta. Requires a
  subagent-spawning tool; without one it must decline rather than simulate.
license: MIT
compatibility: >-
  PORTABILITY: the claim-extraction, grouping, and delta discipline port to any
  harness. The pipeline itself needs a subagent-spawning tool; where none
  exists, Step 0 requires this skill to decline and fall back to search-based
  verification rather than fabricate a result. This skill is harness-agnostic
  in judgment and gated only on that one capability.
---

# Second Opinion

Stress-tests a verdict and re-emits it with per-claim grouping. Companion to
`human-voice`, which produces the verdict this skill validates.

## Invariant

**ALWAYS** confirm a subagent-spawning tool exists before starting, and report
counts that equal what actually ran. **NEVER** run unbidden, and never emit this
skill's output format without having dispatched the work it describes.

## Step 0 — Preconditions

Both must hold before anything else happens.

1. **The user asked.** Either they invoked this skill, or `human-voice` offered
   it and they accepted. **Never auto-run.** Offering means one line naming the
   validation and stopping; the user's next message is the only trigger.

2. **A subagent-spawning tool is actually available.**
   Name the tool you will call. If you cannot name it, you are in the ungated case:

   > State that subagent validation is unavailable here, give the verdict's
   > uncertainty plainly, and offer search-based verification instead.

   **In the ungated case this skill's output format is forbidden** — no grouped
   Verified/Flagged/Conflict block, no `Δ Validation` block, no persona
   attributions, no `❗`. Respond in `human-voice` default mode. Producing the
   shape of a validation that did not run is the single worst failure this skill
   can have.

   **The tell is the structure, not the glyphs.** `human-voice` uses `✅ ⚠️ ❓`
   for ordinary claim confidence, so their presence is not what makes something
   a counterfeit validation — and you do not have to strip your normal tagging
   to comply here. What is forbidden is the *shape* that implies dispatched
   work: group headings named Verified / Flagged / Conflict, a delta line
   reporting counts of checks or personas, positions attributed to named
   advisors, and `❗`. Tag as `human-voice` normally (verdict plus exceptions,
   not every line) and emit none of that structure.

Never run for quick facts or low-stakes picks. Cost consciousness is a design
constraint, not a preference.

## Report only what has come back

There are three states, not two, and the middle one is where fabrication
happens: no tool available (Step 0), **dispatched but nothing returned yet**,
and results in hand.

Until a subagent has actually reported back to you, you have no findings. In
that middle state:

- Say what you are dispatching and what you will check. That is honest.
- **Never state an outcome for a claim.** No `✅`/`⚠️`/`❓` presented as a
  fact-check result, no verdict held/downgraded/flipped, no delta.
- **Never cite a source you have not read.** Writing "verified — AWS docs,
  Postgres docs" when no subagent has returned is inventing evidence, and it is
  worse than saying nothing: the citation is what makes the reader trust it.

A plan is not a result. If your reply would read the same whether or not the
subagents ran, you have written a counterfeit.

## Step 1 — Extract claims

Decompose the verdict into load-bearing claims. A claim is load-bearing if the
verdict weakens when it falls. Skip decorative claims. If extraction itself is
ambiguous — it is unclear what the verdict rests on — ask before spending.

## Step 2 — Budget

Count one unit per subagent call. **Total = fact-check calls + advisor
personas.**

- Default shape: **1 batched fact-check call + ≤3 advisors = 4 units.**
- Fact-checking is **batched**: one subagent receives all load-bearing claims
  and returns a per-claim verdict list. Do not spawn one call per claim.
- **Hard cap 6.** If the plan exceeds 6 units, stop here — before dispatching
  anything — state the exact planned count, and wait for a yes.

## Step 3 — Fact-check

One batched call. Per claim it returns `verified` / `unsupported` /
`contradicted`, each with a terse source: docs, repo, issue, benchmark.

## Step 4 — Advisors

One persona per angle that needs **judgment, not facts** — an SRE for
operational risk, Security for auth and compliance, Cost for spend. Each gets a
scoped brief: the verdict, the relevant claims, and only its angle.

Personas argue from evidence. Every position cites a source or an explicit chain
of reasoning the user can audit.

## Step 5 — Merge

Precedence when a claim matches more than one group:
**Cut > Conflict > Flagged > Verified.**
Any advisor doubt demotes a fact-check-verified claim to Flagged. Without this
order, two runs on the same input disagree.

- ✅ **Verified** — fact-check passed, **or** advisors concur *and each cites a
  source*. Concurrence without sources is `⚠️`, never `✅`.
- ⚠️ **Flagged** — unsupported, unproven, or an advisor raised doubt. Claims
  that entered as `❓` unverified land here once checked.
- ❗ **Conflict** — advisors disagree. Never resolve silently: surface both
  positions with both bases. The user decides.
- **Cut** — contradicted claims leave the response and are **named** in the
  delta, not merely counted.

## Output format

Verdict may hold, downgrade, or flip. The delta says which.

**≤10 claims — inline.** One claim per line, blank line between groups:

```
**<Verdict>** <✅|⚠️|❗> — <N of M advisors concur | advisors split | verdict flipped>

**Verified**

✅ <claim> — *<source>*

**Flagged**

⚠️ <claim> — *<basis>*

**Conflict — your call**

❗ <topic>
- <Persona A>: <position> — *<basis>*
- <Persona B>: <position> — *<basis>*

**Cut**

<claim> — *contradicted by <source>*

**Δ Validation**

Verdict <held|downgraded|flipped> · confidence <before> → <after>
Cut <N> claims · <N> fact-checks across <N> claims · personas: <names> (<N>)
```

**>10 claims — overflow.** Inline keeps the verdict line, the Conflict group,
and the delta; full per-claim detail goes to `validation-report.md`. Link it.

**Zero-change form.** Validation that changes nothing still emits the delta:

```
**Δ Validation**

Verdict held · confidence unchanged
No claims cut · 1 fact-check across 4 claims · personas: SRE, Cost (2)
```

## Rules

- **The delta is mandatory.** Validation that changed nothing must say so.
- **Counts equal reality.** The fact-check and persona counts must equal the
  subagent calls actually dispatched this turn. If a planned call was skipped,
  the count reflects what ran, not what was planned. Never emit a nonzero count
  without a corresponding dispatch.
- **Name personas, don't count them.** `personas: SRE, Security, Cost (3)` — a
  bare number hides an over-cap run and makes a fabricated persona cheap to
  emit.
- **Never inflate confidence.** Advisors concurring without sources yields `⚠️`.
