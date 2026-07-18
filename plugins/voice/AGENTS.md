# AGENTS.md — voice

Three skills that decide how output is written. `human-voice` governs prose a
human reads: verdict first, scannable, claims tagged with a closed confidence
vocabulary. `machine-voice` governs machine-read artifacts — agent traces, logs,
status lines, state dumps, schemas — and compresses them. `second-opinion` is an
offer-only validation pipeline that stress-tests a verdict and re-emits it
grouped into verified, flagged, and conflict.

The three ship together because they are one system: the first two partition a
single decision by reference to each other, and the third is the escalation
target the first one names. Installed apart, each describes a counterpart that
is not there.

## How to use it

Read the skill that matches the element you are about to write:

- `skills/human-voice/SKILL.md` — prose a human reads
- `skills/machine-voice/SKILL.md` — traces, logs, status lines, schemas,
  structured data. Pattern detail lives in
  `skills/machine-voice/references/lexical-patterns.md`
- `skills/second-opinion/SKILL.md` — validating a verdict, only after the user
  accepts the offer

The routing rule is **per output element, not per response**. One reply commonly
contains both: prose sections follow `human-voice`, an embedded trace follows
`machine-voice`. Code and file contents, commit messages, creative writing, and
turns that are only a clarifying question fall outside both.

`commands/voice.md` is the entry point a user invokes to read the routing rule
on demand.

## PORTABILITY: harness-agnostic, with one optional convenience

The skills are plain prose discipline and port to any coding agent. This plugin
also ships an optional Claude Code session-start hook — `hooks/hooks.json` and
`hooks-handlers/session-start.sh` — which injects the routing rule as additional
context so the right skill is consulted without being asked.

That hook is a **convenience, never a dependency**. On a harness that does not
read `hooks/hooks.json`, nothing breaks: the skills are selected the ordinary
way, by their descriptions. No skill's instructions depend on the hook having
run, and none of them claim to be invoked by it.

`second-opinion` has one genuine capability requirement — a subagent-spawning
tool. Where none exists it is required to decline and fall back to search-based
verification rather than simulate a result.

## The invariant this plugin defends

> ALWAYS route each output element to exactly one voice — prose to
> `human-voice`, machine-read artifacts to `machine-voice`. NEVER run
> `second-opinion` unbidden, and never emit its validation format without having
> actually dispatched the subagents it reports.

The second clause is the one with teeth. A model that emits a grouped
Verified/Flagged/Conflict block and a delta line without having dispatched
anything has produced a counterfeit of exactly the thing the user asked for when
they said "are you sure" — indistinguishable from the real output, and worse
than no answer.

The deterministic checks that defend it live in `evals/cheap/checks.sh` and run
as part of the marketplace cheap tier. The prose-level behaviour — that the
partition routes correctly and that the ungated case refuses to fabricate — is
defended by the behavioral tier in `evals/promptfoo/promptfooconfig.yaml`.
