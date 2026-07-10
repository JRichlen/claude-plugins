# Handoff brief — <plugin-or-skill-name>

> **What this file is.** The durable spec for one plugin/skill build. It is the
> *handoff seam* (winner #7): the build's state lives in this committed file, not
> in one conversation's scrollback. Any harness — Claude Code today, Codex or a
> cron job tomorrow — picks the work up by reading this brief, not by replaying a
> transcript it can't see. Commit it alongside the skill; update it as the build
> converges. If you can delete every chat window and a fresh agent can still
> continue from these three files (`BRIEF.md`, `INTENT.md`, `STUCK.md`), the seam
> is doing its job.

## What it must do
<One paragraph: the capability this skill gives the model. Concrete, not aspirational.>

## The invariant
<The one property that must hold on every invocation — the thing the cheap/behavioral
evals defend. State it as a testable claim, e.g. "never emits an unbundled delete."
If you can't name an invariant, the skill isn't ready for an eval tier yet.>

## When it should trigger
<The user phrases / contexts that should pull this skill in. This becomes the
description frontmatter, so phrase it the way a real request arrives.>

## Output shape
<What a correct run produces: files, format, side effects. Name the observable
artifact an eval can grade.>

## Eval plan
- **cheap:** <deterministic checks — parse, shape, invariant-as-substring.>
- **behavioral:** <the prose-steers-behavior rubric, or "n/a — subjective output".>
- **deep:** <cross-harness end-to-end, or "n/a until a safety invariant lands".>

## Baseline for the delta gate
<Path to the no-skill (or prior-skill) baseline this build is measured against.
The delta gate scores *lift over this baseline* — see references/skill-iteration.md.
A build with no baseline recorded here cannot compute lift, so the gate stays advisory.>

## Open questions
<Anything a resuming agent must resolve before it can safely continue. Empty = ready.>
