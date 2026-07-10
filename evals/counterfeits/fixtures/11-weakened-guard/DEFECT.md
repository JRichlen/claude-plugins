# Counterfeit: destructive emit with its confirmation guard removed

**Gate exercised:** the plugin's OWN sourced safety pack
(`plugins/sample-guard/evals/cheap/checks.sh`, assertion B), reached via cheap
tier section 10.

**Defect:** `emit.sh` is replaced with a still-valid-bash version that emits a
bare `rm -rf` with no confirmation guard. Nothing about the *structure* of the
plugin is broken — the JSON is valid, the shell parses, the pack still exists —
so gates 1–10 of the shared runner all stay green. The ONLY thing that fails is
the plugin's own invariant check.

This is the most important counterfeit in the corpus: it proves the fail-closed
per-plugin discovery (section 10) does more than assert a pack *file is present*
— it proves a sourced safety pack actually **bites**, catching a real weakening
of the safety invariant that no structural gate would ever see. A corpus that
only broke JSON and shell syntax would leave this — the whole reason the deep
discipline exists — unproven.

EXPECT_FAIL_SUBSTRING=MISSING its confirmation guard
