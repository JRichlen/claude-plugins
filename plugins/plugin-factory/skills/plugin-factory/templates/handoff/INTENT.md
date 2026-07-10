# Capture-intent record — <plugin-or-skill-name>

> **What this file is.** The answers to skill-creator's four Capture-Intent
> questions, frozen in a committed file so the intent survives the conversation
> that produced it. The wrapped skill-creator (winner #9, pinned in
> `vendor/skill-creator.pin`) starts every build by capturing intent; this file
> is where we persist that capture so a later iteration — possibly on a different
> harness — reads the *decisions*, not a summary of a chat it never saw. It is
> deliberately separate from `BRIEF.md`: the brief is the spec that keeps
> evolving; this is the original intent, changed only when the goal itself moves.

## 1. What should this skill enable?
<The capability, in the user's own framing.>

## 2. When should it trigger?
<Phrases / contexts. Feeds the description frontmatter — undertriggering is the
common failure, so err toward naming the situations explicitly.>

## 3. Expected output format?
<The shape of a correct result.>

## 4. Test cases: yes or no — and why?
<Objectively-verifiable output (file transforms, extraction, fixed steps) → yes,
set up evals. Subjective output (style, art) → often no. Record the call and the
reason, so a resuming agent doesn't relitigate it.>

## Decisions locked
<Anything settled during the interview that later iterations must not silently
reverse — a format choice, a scope boundary, a dependency ruled out. Each line is
a decision a fresh harness inherits instead of re-deriving.>
