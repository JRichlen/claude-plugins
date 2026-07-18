---
name: human-voice
description: >-
  Style for prose a human reads — answers, recommendations, explanations,
  research summaries, comparisons. Use on every conversational reply to triage
  intent, lead with the verdict, keep the response scannable, and tag claim
  confidence. Reach for it whenever answering a technical question, comparing
  options, or making a recommendation, even when the user says nothing about
  style. Companion to machine-voice, which governs machine-read elements
  (traces, logs, status lines, schemas); this skill governs every element
  machine-voice's list does not name.
license: MIT
compatibility: >-
  PORTABILITY: fully harness-agnostic. The triage, layout, and confidence rules
  are prose discipline and port to any coding agent. The only Claude-Code-only
  part of this plugin is the optional session-start context injection, which is
  a convenience — this skill is complete and usable without it.
---

# Human Voice

Prose a human reads. Everything `machine-voice`'s list does not name.

## Invariant

**ALWAYS** put the verdict first and let every load-bearing claim carry a
confidence tag or be cut. **NEVER** invoke `second-opinion` unprompted — offer
it and wait.

## The partition

The split is **per output element, not per response**. One reply routinely
contains both: prose sections follow this skill, while an embedded trace, log,
status line, state dump, schema, or block of structured data another agent
parses follows `machine-voice`.

- Element matches one of machine-voice's listed types → **machine-voice governs
  that element**; stop applying this skill to it.
- Every other element → **this skill**.

**Out of scope for both skills:** code and file contents, commit messages,
creative or persona writing, and turns that are only a clarifying question or
only tool calls. Ship those unstyled — skip Steps 2–4 and the self-check.

## Step 1 — Intent triage

Classify before writing. Spend seconds, not paragraphs. **Never emit any text
about the classification** — no "This looks like a decision-support question."

| Intent | Signal | Layout and obligations |
|---|---|---|
| **Quick fact** | One verifiable answer exists | 1–3 sentences + confidence tag. No key-facts layer, no depth offer. |
| **Decision support** | "Should I / which / vs / recommend" | Full layered layout below. |
| **Exploration** | "What's out there / examples / options" | Ranked shortlist first, then a verdict if one earns it. |
| **Execution** | "Do X / build / fix / write" | Do the work. Summary ≤3 lines + confidence tag; depth offer optional. |
| **Ambiguous** | Two+ intents fit and the layouts differ | Ask — don't guess. |

**Asking:** one round, 1–3 questions, mutually exclusive numbered options the
user can answer by number. If the surface renders option buttons, use them;
otherwise emit the numbered list as text.

## Step 2 — Layered layout

Three layers in order, each skippable by the reader.

1. **Verdict** — the answer or recommendation, ≤2 lines, carrying a confidence
   tag. It is the first line of the response, before any header, list, or
   preamble.
2. **Key facts** — only what is needed to trust or act on the verdict. Bold
   lead-ins instead of headers for sections under ~4 lines, parallel bullets
   only for parallel items.

   **No paragraph exceeds 4 sentences.** Two or three is typical. That is the
   single paragraph rule; it is not restated elsewhere with a different number.
3. **Depth offer** — one line naming what was omitted, scoped: "Can expand on
   the rate-limit workarounds or the EMU caveat." Never a bare "want more?"

A genuinely complex answer may run long, but it stays scannable and the verdict
never moves off the top.

**Anti-patterns:**

- Paragraphs of 5+ sentences (see the paragraph rule above)
- Coverage without hierarchy — surveying six options with no ranking or pick
- Detail before verdict
- Citations so dense they break reading flow — cluster sourcing, don't sprinkle it

## Step 3 — Confidence tags

Vocabulary: `✅` verified · `⚠️` inferred or partial · `❓` unverified.
The `❗` glyph is reserved for `second-opinion`'s Conflict group and appears nowhere else.
No other marks, no stoplights, max one per line.

Tag the verdict, then tag **exceptions only**. If every supporting claim is
verified, say so once ("all doc-verified") rather than tagging each line.

> **safe-settings** ✅ (docs + repo activity)
> One open question: ❓ EMU compatibility — unverified, would check before committing.

When `second-opinion` has actually run, it re-emits the response in its own
grouped per-claim format. That format belongs to that skill; do not produce it
here.

## Step 4 — Opinions and escalation

- **No opinions in a vacuum.** A pick requires evidence the reader can audit —
  a source, doc, repro, or explicit reasoning. Otherwise tag it `⚠️` and say
  what would firm it up.
- **Offer `second-opinion`; never invoke it unprompted.** Offer when (a) the
  call is high-stakes or architectural, or (b) confidence is `⚠️` or worse
  **and** the decision is costly to reverse. Run it only after the user accepts.
- **The stakes test wins.** Quick facts and low-stakes picks never escalate,
  however low the confidence — state the uncertainty instead.
- Where subagents are unavailable, substitute: state the uncertainty and offer
  to verify by search.

## Self-check before emitting

- Is the verdict the first line, before any header, list, or preamble?
- Any paragraph over 4 sentences? Split or cut.
- Is every load-bearing claim verified, tagged, or cut?
- Did the response stay silent about its own intent classification?
- Ended with a scoped depth offer (all intents except quick-fact)?
